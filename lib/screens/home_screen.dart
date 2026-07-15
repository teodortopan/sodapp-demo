import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../demo/demo_mode.dart';
import '../services/auth_service.dart';
import '../services/photo_file_helper.dart';
import '../utils/logical_clock.dart';
import '../utils/uid_gen.dart';
import '../services/banner_service.dart';
import '../services/sync_service.dart';
import '../database/app_database.dart';
import '../utils/argentina_time.dart';
import 'carga_screen.dart';
import 'ruta_screen.dart';
import 'cierre_screen.dart';
import 'configuracion_screen.dart';
import 'clientes_screen.dart';
import 'etiquetas_screen.dart';
import 'resumen_historial_screen.dart';
import 'resumen_anual_screen.dart';
import 'profile_screen.dart';
import 'gastos_screen.dart';
import 'mas_screen.dart';
import 'notifications_screen.dart';
import '../utils/app_tokens.dart';
import '../utils/pack_format.dart';
import '../widgets/sync_indicator.dart';
import '../services/onboarding_service.dart';
import '../services/recorrido_notification_service.dart';
import '../widgets/onboarding/coachmark_step.dart';
import '../widgets/onboarding/coachmark_overlay.dart';
import '../widgets/onboarding/tutorial_controller.dart';
import '../widgets/onboarding/guided_tutorial_overlay.dart';

/// Sections offered by the tutorial replay picker (Más → Tutorial).
enum _TutorialSection { completo, inicio, perfil, cargaRuta, mas }

class _RecorridoState {
  final DateTime start;
  final String fecha;
  final String semana;
  final int day;
  final Duration pastSessionsAccumulated;
  // v85 «Instancias»: which vista started this recorrido. Synced on the
  // persisted entry so the delete-guard and the web EN VIVO badge can
  // attribute it. 'default:<repartoId>' for the implicit main vista.
  final String instanceId;
  _RecorridoState({
    required this.start,
    required this.fecha,
    required this.semana,
    required this.day,
    required this.instanceId,
    this.pastSessionsAccumulated = Duration.zero,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // Onboarding tutorial (Inicio coachmark).
  final GlobalKey _kHeaderText = GlobalKey();
  final GlobalKey _kBell = GlobalKey();
  final GlobalKey _kHojaDeRuta = GlobalKey();
  final GlobalKey _kStats = GlobalKey();
  final GlobalKey _kCarga = GlobalKey();
  final GlobalKey _kGastos = GlobalKey();
  final GlobalKey _kDayBtn = GlobalKey();
  final GlobalKey _kCargaSummary = GlobalKey();
  final GlobalKey _kEmpezar = GlobalKey();
  final GlobalKey _kMasNav = GlobalKey();
  final GlobalKey _kInicioNav = GlobalKey();
  final GlobalKey _kTerminar = GlobalKey();
  final GlobalKey _kInstanceDropdown = GlobalKey();
  final CoachmarkController _coachmark = CoachmarkController();
  bool _tutorialActive = false;
  bool _localeInitialized = false;
  String? _userName;
  String? _userPhotoPath;
  bool _userPhotoFileExists = false;
  List<Reparto> _repartos = [];
  Reparto? _activeReparto;
  StreamSubscription<DemoAuthState>? _authSub;

  // Configurar reparto state
  bool _configExpanded = false;
  int _configSelectedDay = -1; // -1 = none selected
  bool _repartoConfirmed = false;
  Map<int, int> _configCarga = {}; // productId -> cantidad
  // Productos with a configured pack_size (productId -> pack size).
  // Used to pack-adjust the totalCarga shown in the Inicio fraction so
  // the denominator matches the PRODUCTOS tile in Carga (which divides
  // pack products by their pack size).
  Map<int, int> _configPackSizes = {};
  Map<int, int> _configRemanente = {}; // productId -> rolled-over qty
  List<Producto> _configProducts = [];

  // Product ranking state
  List<_RankedProduct> _rankedProducts = [];
  // ignore: unused_field
  int _monthDaysActive = 0;
  // ignore: unused_field
  int _monthTotalUnits = 0;
  // ignore: unused_field
  int _monthUniqueClientes = 0;
  // ignore: unused_field
  int _monthBestDayUnits = 0;
  // ignore: unused_field
  String? _monthBestDayLabel;
  // Daily units for the last 7 days (index 0 = 6 days ago, 6 = today)
  List<int> _last7DaysUnits = List<int>.filled(7, 0);
  // ignore: unused_field
  final bool _showAllRanking = false;

  // Chronometer state — supports multiple simultaneous recorridos.
  // v85 «Instancias»: keyed by '$repartoId:$day' (matching the persisted
  // entries' natural key) so TWO DAYS of the SAME reparto can run at the
  // same time — the whole point of the vistas feature.
  final Map<String, _RecorridoState> _activeRecorridos = {};
  final Map<int, Set<int>> _endedRecorridoDays = {};
  Timer? _chronoTimer;
  late final AnimationController _recorridoPulseCtrl;

  String _rkey(int repartoId, int day) => '$repartoId:$day';

  /// The CURRENT context's recorrido: active reparto + the day the
  /// current vista has selected. Other vistas' recorridos keep running
  /// in the background map; the Inicio hero/chronometer follows this one.
  _RecorridoState? get _currentRecorrido {
    final id = _activeReparto?.id;
    if (id == null || _configSelectedDay < 0) return null;
    return _activeRecorridos[_rkey(id, _configSelectedDay)];
  }

  /// All running recorridos of one reparto (any day / any vista).
  Iterable<_RecorridoState> _recorridosForReparto(int repartoId) sync* {
    final prefix = '$repartoId:';
    for (final e in _activeRecorridos.entries) {
      if (e.key.startsWith(prefix)) yield e.value;
    }
  }

  /// Whether the current vista's (reparto, day) has an active recorrido
  bool get _isRecorridoForCurrentReparto => _currentRecorrido != null;

  /// Whether ANY reparto has an active recorrido
  bool get _anyRecorridoActive => _activeRecorridos.isNotEmpty;

  /// Elapsed time for the current context's recorrido
  Duration get _currentElapsed {
    final state = _currentRecorrido;
    if (state == null) return Duration.zero;
    return DateTime.now().difference(state.start) +
        state.pastSessionsAccumulated;
  }

  static const List<String> _allDayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  List<int> _workDays = [0, 1, 2, 3, 4, 5];
  int _rutaRefreshTrigger = 0;

  // ─── v85 «Instancias» (vistas) ───
  // The synced registry (user_settings.instances_json, merged per entry
  // cross-device) + this DEVICE's current vista per reparto. The pointer
  // is deliberately device-local (SharedPreferences): two soderos on two
  // phones each look at their own vista — that's the feature.
  List<Map<String, dynamic>> _instancesAll = [];
  final Map<int, String> _currentInstancePointers = {};
  static const String _kBaseInstancePrefPrefix = 'instancia.actual.';
  String get _instancePrefPrefix =>
      kDemoMode ? 'demo.$_kBaseInstancePrefPrefix' : _kBaseInstancePrefPrefix;

  String _defaultInstanceId(int repartoId) => 'default:$repartoId';

  bool _isDefaultInstanceId(String id) => id.startsWith('default:');

  String _currentInstanceIdFor(int repartoId) =>
      _currentInstancePointers[repartoId] ?? _defaultInstanceId(repartoId);

  /// Visible (non-deleted) vistas of one reparto, default NOT included —
  /// the default is implicit and synthesized at display time.
  List<Map<String, dynamic>> _instancesForReparto(int repartoId) {
    final list = _instancesAll
        .where(
          (e) =>
              e['repartoId'] == repartoId &&
              e['deleted'] != true &&
              !_isDefaultInstanceId((e['id'] as String?) ?? ''),
        )
        .toList();
    list.sort(
      (a, b) => ((a['createdAtMs'] as num?) ?? 0).compareTo(
        (b['createdAtMs'] as num?) ?? 0,
      ),
    );
    return list;
  }

  Map<String, dynamic>? _instanceById(String id) {
    for (final e in _instancesAll) {
      if (e['id'] == id && e['deleted'] != true) return e;
    }
    return null;
  }

  /// Display name. The default vista may have a stored rename entry under
  /// its synthetic id; otherwise the literal default label.
  String _instanceLabel(int repartoId, String instanceId) {
    final entry = _instanceById(instanceId);
    if (entry != null) {
      final nombre = (entry['nombre'] as String?)?.trim() ?? '';
      if (nombre.isNotEmpty) return nombre;
    }
    return _isDefaultInstanceId(instanceId) ? 'Vista principal' : 'Vista';
  }

  /// The current vista of the ACTIVE reparto, or null when on the default.
  String? get _currentNonDefaultInstanceName {
    final id = _activeReparto?.id;
    if (id == null) return null;
    final instId = _currentInstanceIdFor(id);
    if (_isDefaultInstanceId(instId)) return null;
    return _instanceLabel(id, instId);
  }

  // Live recorrido stats (updated from RutaScreen callback)
  int _liveClientesVisited = 0;
  int _liveClientesTotal = 0;
  int _liveProductosBought = 0;
  double _liveRecaudado = 0;
  double _liveDeudaTotal = 0;
  bool _hasDeferredWithPayment = false;
  // Snapshot stats that persist after recorrido ends (until midnight)
  final Map<int, Set<int>> _completedTodayDays = {};
  bool get _hasCompletedCurrentReparto {
    final id = _activeReparto?.id;
    if (id == null || _configSelectedDay < 0) return false;
    return _completedTodayDays[id]?.contains(_configSelectedDay) ?? false;
  }

  bool get _showStats {
    final id = _activeReparto?.id;
    if (id == null || _configSelectedDay < 0) return false;
    if (_currentRecorrido != null) return true;
    return _hasCompletedCurrentReparto;
  }

  // Última vez data (from last resumen for same day-of-week, excluding today)
  double _ultimaVezRecaudado = 0;
  int _ultimaVezDuracion = 0; // seconds
  // Today's completed recorrido duration (from finalized resumen)
  int _todayDuracion = 0; // seconds

  final _db = AppDatabase.instance;

  // Today's resumen (created at day start for pre-recorrido gastos)
  int? _todayResumenId;
  List<Map<String, dynamic>> _todayGastos = []; // manual gastos only
  // Last gastos JSON we wrote to the DB. Lets _saveTodayGastos short-
  // circuit when nothing actually changed — without it, every cycle
  // of _loadConfigCarga → _saveTodayGastos → onDataChanged →
  // _handleDbDataChanged → _loadRepartos → _loadConfigCarga loops
  // forever at the debounce cadence (300ms).
  String? _lastSavedGastosJson;
  int? _lastSavedGastosResumenId;
  bool _cargaGastosEnabled = true;

  /// Compute product-based gastos from newly purchased packs × wholesale
  /// cost (`productos.precio` — the value edited under the MAYORISTA
  /// section of the producto edit panel — which is the price of the WHOLE
  /// pack). UNIT MISMATCH (important): `cantidad` is stored in INDIVIDUAL
  /// UNITS (the carga dialog enters packs and multiplies by pack_size), but
  /// `remanente` is stored as the ENTERED PACK COUNT (no pack multiply). So we
  /// must convert remanente to units (× packSize) before subtracting, then
  /// divide the newly-purchased units by pack_size to bill per pack:
  /// gasto = mayorista × (cantidad − remanente×packSize) ÷ packSize. Non-pack
  /// items use packSize 1, so this is just mayorista × (cantidad − remanente).
  /// Products without a mayorista cost set are EXCLUDED. Entries are stamped
  /// `v:2` so a future historical recompute can skip already-correct rows.
  List<Map<String, dynamic>> get _productGastos {
    if (!_cargaGastosEnabled) return <Map<String, dynamic>>[];
    final result = <Map<String, dynamic>>[];
    for (final p in _configProducts) {
      final qty = _configCarga[p.id] ?? 0;
      final rem = _configRemanente[p.id] ?? 0;
      final packSize = _configPackSizes[p.id] ?? 1;
      final effectivePackSize = packSize >= 2 ? packSize : 1;
      // remanente is in PACKS; convert to units before subtracting from the
      // unit-based cantidad.
      final newlyPurchased = (qty - rem * effectivePackSize).clamp(0, qty);
      if (newlyPurchased <= 0) continue;
      final mayorista = p.precio;
      if (mayorista <= 0) continue;
      result.add({
        'descripcion': '${p.nombre} (x$newlyPurchased)',
        'monto': mayorista * newlyPurchased / effectivePackSize,
        'type': 'producto',
        'producto_id': p.id,
        'v': 2,
      });
    }
    return result;
  }

  /// All gastos combined (product + manual) for display and saving.
  List<Map<String, dynamic>> get _allGastos => [
    ..._productGastos,
    ..._todayGastos,
  ];
  final _homeGastoDescCtrl = TextEditingController();
  final _homeGastoMontoCtrl = TextEditingController();
  final _inicioScrollCtrl = ScrollController();
  final _gastoDescFocus = FocusNode();
  final _gastoMontoFocus = FocusNode();
  bool _gastoFieldFocused = false;
  bool _cargaGastoExpanded = false;

  // Notification state
  int _unreadNotifCount = 0;
  int _unreadAdminMessageCount = 0;
  StreamSubscription<int>? _unreadAdminMessageSub;
  StreamSubscription<int>? _unreadNotifSub;

  AppTokens get tokens => AppTokens.of(context);

  Timer? _midnightTimer;
  Timer? _repartosReloadDebounce;
  late final void Function() _dbDataListener = _handleDbDataChanged;
  late final void Function() _dbLocalDataListener = _handleDbLocalDataChanged;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorridoPulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _initLocale();
    _loadUserName();
    _loadUserProfileLocal();
    _loadCargaGastosEnabled();
    // v85: vista pointers + registry must be in memory BEFORE the
    // recorrido restore so the restore can focus the right vista.
    _loadInstancePointers()
        .then((_) => _loadInstances())
        .then((_) => _loadRepartos())
        .then((_) => _restoreRecorrido());
    _loadWorkDays();
    _checkAllNotifications();
    _loadUnreadCount();
    // Reactive total-unread count for the bell's number badge — fires on
    // every insert/mark-read/delete in app_notifications so the badge
    // doesn't go stale between manual _loadUnreadCount calls.
    _unreadNotifSub = _db.watchUnreadNotificationCount().listen((count) {
      if (mounted) setState(() => _unreadNotifCount = count);
    });
    _unreadAdminMessageSub = _db.watchUnreadAdminMessageCount().listen((count) {
      if (mounted) setState(() => _unreadAdminMessageCount = count);
    });
    _scheduleMidnightCheck();
    _listenAuthState();
    _gastoDescFocus.addListener(_onGastoFocusChanged);
    _gastoMontoFocus.addListener(_onGastoFocusChanged);
    TutorialController.instance.onExit = _handleGuidedTutorialExit;
    TutorialController.instance.onScreenRequested = _handleGuidedScreenRequest;
    // "Terminar" tapped on the lock-screen recorrido notification → route into
    // the normal end-recorrido flow (confirm dialog → cierre). Never silent.
    RecorridoNotificationService.instance.onTerminarRequested =
        _onNotificationTerminar;
    // Phase 3 update: leave `_configSelectedDay = -1` (no day picked) so the
    // sodero always explicitly selects a day via SELECCIONAR DÍA. The button
    // gates EMPEZAR RECORRIDO behind a real choice.
    // After sign-in, the cloud restore can finish AFTER HomeScreen has
    // already mounted with an empty local DB — leaving the sodero stuck
    // with no reparto. Re-load repartos when the DB notifies a change so the
    // post-restore state lands in the UI without manual refresh. Debounce to
    // avoid making every entrega/pago write fan out into repeated route loads.
    _db.addDataListener(_dbDataListener);
    _db.addLocalDataListener(_dbLocalDataListener);
    _maybeAutoStartTutorial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _db.removeDataListener(_dbDataListener);
    _db.removeLocalDataListener(_dbLocalDataListener);
    _authSub?.cancel();
    _unreadAdminMessageSub?.cancel();
    _unreadNotifSub?.cancel();
    _chronoTimer?.cancel();
    _recorridoPulseCtrl.dispose();
    _midnightTimer?.cancel();
    _repartosReloadDebounce?.cancel();
    _homeGastoDescCtrl.dispose();
    _homeGastoMontoCtrl.dispose();
    _coachmark.dismiss();
    TutorialController.instance.onExit = null;
    TutorialController.instance.onScreenRequested = null;
    RecorridoNotificationService.instance.onTerminarRequested = null;
    _inicioScrollCtrl.dispose();
    _gastoDescFocus.dispose();
    _gastoMontoFocus.dispose();
    super.dispose();
  }

  void _handleDbDataChanged() {
    if (!mounted) return;
    _repartosReloadDebounce?.cancel();
    _repartosReloadDebounce = Timer(Duration(milliseconds: 300), () {
      if (mounted) {
        _loadRepartos();
        _loadUserProfileLocal();
        _loadCargaGastosEnabled();
        // Producto edits (mayorista price, pack size, name) fire
        // onDataChanged but carga_screen's onCargaChanged callback only
        // covers cantidad changes — so without this reload, _configProducts
        // (consumed by _productGastos) keeps a stale precio after a
        // MAYORISTA save and gastos shows the wrong number.
        _loadConfigCarga();
        // v85: cloud merges can add/rename/delete vistas — keep the
        // dropdown registry fresh.
        _loadInstances();
        // v85: and they can start/end/reactivate recorridos from OTHER
        // phones — reconcile the in-memory chronometer map so the hero,
        // EN VIVO chips and notification reflect reality without an app
        // restart.
        _reconcileRecorridosFromDb();
      }
    });
  }

  void _handleDbLocalDataChanged() {
    if (mounted) _loadUserProfileLocal();
  }

  /// v85: bring [_activeRecorridos] in line with the persisted entries
  /// after a sync merge. The DB is the truth — every mutation (ours and
  /// every sibling phone's) lands there first.
  ///
  ///   • A memory entry whose persisted twin is gone/ended/cleared was
  ///     closed elsewhere → drop it (the chrono stops; the day moves to
  ///     the ended set so the Reanudar/Finalizar affordances show).
  ///   • An unended persisted entry missing from memory (sibling started
  ///     it) is ADOPTED so switching to that vista shows the running
  ///     chronometer immediately — the «see the Thursday chrono running»
  ///     half of the feature. Adoption never changes the focused day.
  ///   • A start-time change (sibling reactivated) refreshes the state;
  ///     the CURRENT context recomputes its pastAccum (visible chrono),
  ///     background entries keep/skip it lazily — the vista-switch path
  ///     recomputes on focus.
  Future<void> _reconcileRecorridosFromDb() async {
    List<Map<String, dynamic>> persisted;
    try {
      persisted = await _db.getActiveRecorridos();
    } catch (_) {
      return;
    }
    final unendedByKey = <String, Map<String, dynamic>>{};
    final endedByKey = <String, Map<String, dynamic>>{};
    for (final e in persisted) {
      final repartoId = e['repartoId'];
      final day = e['day'];
      if (repartoId is! int || day is! int) continue;
      final key = _rkey(repartoId, day);
      if (_isEndedRecorridoEntry(e)) {
        endedByKey[key] = e;
      } else {
        unendedByKey[key] = e;
      }
    }

    var changed = false;
    final currentKey = (_activeReparto != null && _configSelectedDay >= 0)
        ? _rkey(_activeReparto!.id, _configSelectedDay)
        : null;

    // Drop what was closed elsewhere.
    for (final key in _activeRecorridos.keys.toList()) {
      if (unendedByKey.containsKey(key)) continue;
      final state = _activeRecorridos.remove(key);
      changed = true;
      if (state != null && endedByKey.containsKey(key)) {
        final repartoId = int.tryParse(key.split(':').first);
        if (repartoId != null) {
          _endedRecorridoDays
              .putIfAbsent(repartoId, () => <int>{})
              .add(state.day);
        }
      }
    }

    // Adopt / refresh what runs elsewhere.
    for (final entry in unendedByKey.entries) {
      final key = entry.key;
      final e = entry.value;
      final repartoId = e['repartoId'] as int;
      final day = e['day'] as int;
      final startMillis = (e['startMillis'] as num?)?.toInt();
      if (startMillis == null) continue;
      final mem = _activeRecorridos[key];
      final owner =
          (e['instanceId'] as String?) ?? _defaultInstanceId(repartoId);
      if (mem != null &&
          mem.start.millisecondsSinceEpoch == startMillis &&
          mem.instanceId == owner) {
        continue; // already in sync
      }
      // Don't adopt for repartos we no longer have (deleted mid-merge).
      if (!_repartos.any((r) => r.id == repartoId)) continue;
      final startArg = _argDateFromEpochMillis(startMillis);
      final fecha = (e['fecha'] as String?) ?? argFecha(startArg);
      final semana =
          (e['semana'] as String?) ?? argentinaWeekString(at: startArg);
      var pastAccum = mem?.pastSessionsAccumulated ?? Duration.zero;
      if (key == currentKey) {
        try {
          pastAccum = await _computeRepartoPastSessions(
            repartoId,
            fecha,
            semana,
            day,
          );
        } catch (_) {}
      }
      _activeRecorridos[key] = _RecorridoState(
        start: DateTime.fromMillisecondsSinceEpoch(startMillis),
        fecha: fecha,
        semana: semana,
        day: day,
        instanceId: owner,
        pastSessionsAccumulated: pastAccum,
      );
      _endedRecorridoDays[repartoId]?.remove(day);
      if (_endedRecorridoDays[repartoId]?.isEmpty ?? false) {
        _endedRecorridoDays.remove(repartoId);
      }
      changed = true;
    }

    if (!changed || !mounted) return;
    setState(() {});
    if (_activeRecorridos.isEmpty) {
      _chronoTimer?.cancel();
      _chronoTimer = null;
    } else {
      _ensureChronoTimer();
    }
    _syncRecorridoNotificationOnEnd();
  }

  // ─── v85 «Instancias» loading + lifecycle ───

  Future<void> _loadInstancePointers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_instancePrefPrefix)) continue;
        final repartoId = int.tryParse(
          key.substring(_instancePrefPrefix.length),
        );
        final value = prefs.getString(key);
        if (repartoId != null && value != null && value.isNotEmpty) {
          _currentInstancePointers[repartoId] = value;
        }
      }
    } catch (e) {
      debugPrint('[HOME] _loadInstancePointers failed: $e');
    }
  }

  Future<void> _setCurrentInstancePointer(
    int repartoId,
    String instanceId,
  ) async {
    _currentInstancePointers[repartoId] = instanceId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_instancePrefPrefix$repartoId', instanceId);
    } catch (e) {
      debugPrint('[HOME] persisting vista pointer failed: $e');
    }
  }

  Future<void> _loadInstances() async {
    try {
      final list = await _db.getInstancesRaw();
      if (!mounted) return;
      var pointerHealed = false;
      setState(() {
        _instancesAll = list;
        // Heal pointers at non-existent / deleted vistas (deleted on
        // another phone while this one pointed at them) back to default.
        for (final entry in _currentInstancePointers.entries.toList()) {
          final id = entry.value;
          if (_isDefaultInstanceId(id)) continue;
          if (_instanceById(id) == null) {
            _currentInstancePointers[entry.key] = _defaultInstanceId(entry.key);
            pointerHealed = true;
            if (_activeReparto?.id == entry.key) {
              // The vista under our feet vanished (deleted on a sibling
              // phone). If ITS day's recorrido is RUNNING here — the
              // sodero is mid-route — keep the day context; only the
              // registry pointer moves to the default vista. Dropping
              // the route mid-marking would strand them.
              final running =
                  _configSelectedDay >= 0 &&
                  _activeRecorridos.containsKey(
                    _rkey(entry.key, _configSelectedDay),
                  );
              if (!running) {
                // Idle context — drop back to the default vista cleanly.
                _configSelectedDay = -1;
                _repartoConfirmed = false;
                _todayResumenId = null;
                _todayGastos = [];
              }
            }
          }
        }
      });
      if (pointerHealed) {
        final prefs = await SharedPreferences.getInstance();
        for (final e in _currentInstancePointers.entries) {
          if (_isDefaultInstanceId(e.value)) {
            await prefs.remove('$_instancePrefPrefix${e.key}');
          }
        }
      }
    } catch (e) {
      debugPrint('[HOME] _loadInstances failed: $e');
    }
  }

  /// Switch the active reparto's context to [instanceId]: persist the
  /// pointer, restore that vista's day (its configured day, or the day of
  /// the recorrido it owns), and reload the per-day context (carga
  /// summary, gastos/resumen, última vez). Business data is untouched —
  /// a vista is a lens, never a copy.
  Future<void> _switchToInstance(String instanceId) async {
    final reparto = _activeReparto;
    if (reparto == null) return;
    await _setCurrentInstancePointer(reparto.id, instanceId);

    int day = -1;
    final entry = _instanceById(instanceId);
    final configuredDay = (entry?['day'] as num?)?.toInt();
    if (configuredDay != null && configuredDay >= 0) {
      day = configuredDay;
    }
    // A recorrido owned by this vista trumps the configured day.
    for (final s in _recorridosForReparto(reparto.id)) {
      if (s.instanceId == instanceId) {
        day = s.day;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _configSelectedDay = day;
      _repartoConfirmed = day >= 0;
      _configExpanded = false;
      _todayResumenId = null;
      _todayGastos = [];
    });
    _loadConfigCarga();
    if (day >= 0) {
      _loadUltimaVez();
      await _ensureTodayResumen();
    }
  }

  /// v85: when the current vista (non-default) picks a day, persist it on
  /// the synced registry entry so every phone sees «Feriado → Viernes».
  Future<void> _persistInstanceDaySelection(int day) async {
    final repartoId = _activeReparto?.id;
    if (repartoId == null) return;
    final instanceId = _currentInstanceIdFor(repartoId);
    if (_isDefaultInstanceId(instanceId)) return;
    await _db.mutateInstancesAtomic((list) {
      for (final e in list) {
        if (e['id'] == instanceId && e['deleted'] != true) {
          if (e['day'] == day) break;
          e['day'] = day < 0 ? null : day;
          e['updatedAtMs'] = LogicalClock.nextMs();
          break;
        }
      }
      return list;
    });
    unawaited(_loadInstances());
  }

  // ─── v85 «Instancias» picker UI ───

  /// Open the vistas dropdown (the chevron next to the date). Refreshes
  /// the registry + the persisted recorrido entries first so EN VIVO
  /// chips reflect OTHER phones' running days too, not just this one's.
  Future<void> _showInstancePicker() async {
    final reparto = _activeReparto;
    if (reparto == null) return;
    final rootContext = context;
    await _loadInstances();
    List<Map<String, dynamic>> persisted = const [];
    try {
      persisted = await _db.getActiveRecorridos();
    } catch (_) {}
    if (!mounted) return;

    final currentId = _currentInstanceIdFor(reparto.id);
    final vistas = <Map<String, dynamic>?>[
      null, // the implicit default vista
      ..._instancesForReparto(reparto.id),
    ];

    ({bool running, int? day}) liveInfoFor(String instanceId) {
      int? day = (_instanceById(instanceId)?['day'] as num?)?.toInt();
      var running = false;
      for (final e in persisted) {
        if (e['repartoId'] != reparto.id) continue;
        if (_isEndedRecorridoEntry(e) || e['cleared'] == true) continue;
        final owner =
            (e['instanceId'] as String?) ?? _defaultInstanceId(reparto.id);
        if (owner == instanceId) {
          running = true;
          day = (e['day'] as num?)?.toInt() ?? day;
          break;
        }
      }
      return (running: running, day: day);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 12, 0, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Vistas de ${reparto.nombre}',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Cada vista corre su propio día — podés repartir '
                      'dos días a la vez en el mismo reparto.',
                      style: TextStyle(color: tokens.textMuted, fontSize: 12),
                    ),
                  ),
                  SizedBox(height: 8),
                  ...vistas.map((v) {
                    final instanceId =
                        (v?['id'] as String?) ?? _defaultInstanceId(reparto.id);
                    final isDefault = v == null;
                    final isCurrent = instanceId == currentId;
                    final live = liveInfoFor(instanceId);
                    final dayLabel =
                        (live.day != null &&
                            live.day! >= 0 &&
                            live.day! < _allDayNames.length)
                        ? _allDayNames[live.day!]
                        : 'Sin día elegido';
                    return ListTile(
                      leading: Icon(
                        isCurrent
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isCurrent
                            ? tokens.primaryBlue
                            : tokens.textMuted,
                      ),
                      title: Text(
                        _instanceLabel(reparto.id, instanceId),
                        style: TextStyle(
                          color: tokens.text,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              dayLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (live.running) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'EN VIVO',
                                style: TextStyle(
                                  color: tokens.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: tokens.textMuted,
                              size: 20,
                            ),
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              _showRenameInstanceDialog(reparto.id, instanceId);
                            },
                          ),
                          if (!isDefault)
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: tokens.danger,
                                size: 20,
                              ),
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                _confirmDeleteInstance(reparto.id, instanceId);
                              },
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        if (!isCurrent) _switchToInstance(instanceId);
                      },
                    );
                  }),
                  Divider(color: tokens.cardBorder, height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.add_circle_outline,
                      color: tokens.primaryBlue,
                    ),
                    title: Text(
                      'Nueva vista',
                      style: TextStyle(color: tokens.primaryBlue),
                    ),
                    onTap: () {
                      if (blockDemoAction(rootContext)) return;
                      Navigator.pop(sheetCtx);
                      _showCreateInstanceDialog(reparto.id);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateInstanceDialog(int repartoId) {
    final controller = TextEditingController();
    final rootContext = context;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Nueva vista',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: tokens.text),
          decoration: InputDecoration(
            hintText: 'Ej: Camión 2, Feriado',
            hintStyle: TextStyle(color: tokens.textMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: tokens.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: tokens.primaryBlue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              if (blockDemoAction(rootContext)) return;
              Navigator.pop(ctx);
              final id = UidGen.next();
              final now = LogicalClock.nextMs();
              await _db.mutateInstancesAtomic(
                (list) => list
                  ..add({
                    'id': id,
                    'repartoId': repartoId,
                    'nombre': name,
                    'day': null,
                    'createdAtMs': now,
                    'updatedAtMs': now,
                  }),
              );
              await _loadInstances();
              await _switchToInstance(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _showRenameInstanceDialog(int repartoId, String instanceId) {
    final controller = TextEditingController(
      text: _instanceById(instanceId)?['nombre'] as String? ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Renombrar vista',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: tokens.text),
          decoration: InputDecoration(
            hintText: _isDefaultInstanceId(instanceId)
                ? 'Vista principal'
                : 'Nombre de la vista',
            hintStyle: TextStyle(color: tokens.textMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: tokens.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: tokens.primaryBlue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _db.mutateInstancesAtomic((list) {
                final now = LogicalClock.nextMs();
                for (final e in list) {
                  if (e['id'] == instanceId && e['deleted'] != true) {
                    e['nombre'] = name;
                    e['updatedAtMs'] = now;
                    return list;
                  }
                }
                // Renaming the implicit default materializes its entry
                // under the stable synthetic id (the merge key).
                list.add({
                  'id': instanceId,
                  'repartoId': repartoId,
                  'nombre': name,
                  'day': null,
                  'createdAtMs': now,
                  'updatedAtMs': now,
                });
                return list;
              });
              await _loadInstances();
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteInstance(int repartoId, String instanceId) async {
    // Guard (Codex review): refuse while THIS vista owns a running recorrido
    // (this phone or any other — the persisted entries carry cross-device
    // state). Ownership is by instanceId on the recorrido entry, so a
    // sibling vista running the same day no longer blocks deleting an idle
    // vista, and a running vista is caught even if its registry day was
    // switched mid-recorrido. Entries from older app versions carry no
    // instanceId — for those, fall back to the configured-day match
    // (best-effort attribution).
    final entry = _instanceById(instanceId);
    final configuredDay = (entry?['day'] as num?)?.toInt() ?? -1;
    var running = false;
    try {
      final actives = await _db.getActiveRecorridos();
      for (final a in actives) {
        if ((a['repartoId'] as num?)?.toInt() != repartoId) continue;
        if (_isEndedRecorridoEntry(a)) continue;
        final owner = (a['instanceId'] as String?)?.trim() ?? '';
        if (owner == instanceId) {
          running = true;
          break;
        }
        if (owner.isEmpty &&
            configuredDay >= 0 &&
            (a['day'] as num?)?.toInt() == configuredDay) {
          running = true;
          break;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    if (running) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Terminá el recorrido de esta vista antes de eliminarla.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar vista',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Eliminar «${_instanceLabel(repartoId, instanceId)}»?\n\n'
          'No se borra ningún dato: las entregas, pagos y resúmenes de '
          'sus días quedan en el reparto.',
          style: TextStyle(color: tokens.textSub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: TextStyle(
                color: tokens.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Soft-delete ONLY the registry entry — vistas are lenses, never data.
    await _db.mutateInstancesAtomic((list) {
      for (final e in list) {
        if (e['id'] == instanceId) {
          e['deleted'] = true;
          e['updatedAtMs'] = LogicalClock.nextMs();
          break;
        }
      }
      return list;
    });
    if (_currentInstanceIdFor(repartoId) == instanceId) {
      await _switchToInstance(_defaultInstanceId(repartoId));
    }
    await _loadInstances();
  }

  Future<void> _loadCargaGastosEnabled() async {
    final enabled = await _db.getCargaGastosEnabled();
    if (!mounted) return;
    final changed = enabled != _cargaGastosEnabled;
    setState(() => _cargaGastosEnabled = enabled);
    if (changed && _todayResumenId != null) {
      await _saveTodayGastos();
    }
  }

  /// Reads the locally-cached profile photo path/URL so the header avatars
  /// can show the picked photo without a network round-trip. Re-runs on
  /// every onDataChanged so picking a new photo in ProfileScreen propagates
  /// back to Inicio.
  Future<void> _loadUserProfileLocal() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    try {
      final row = await _db.getCuentaLocal(userId);
      final path = row?['foto_path'] as String?;
      var pathExists = false;
      if (path != null && path.isNotEmpty) {
        pathExists = await photoExists(path);
      }
      if (!mounted) return;
      setState(() {
        _userPhotoPath = path;
        _userPhotoFileExists = pathExists;
      });
    } catch (_) {
      // Local read shouldn't ever throw; ignore quietly.
    }
  }

  /// Renders the sodero's profile photo if one is cached locally, falling
  /// back to the cloud URL, then to the default person icon. Shared by all
  /// header avatars in this screen.
  Widget _buildUserAvatar({
    required double radius,
    double iconSize = 18,
    Color background = const Color(0x33FFFFFF),
    Color iconColor = Colors.white,
  }) {
    ImageProvider? image;
    final path = _userPhotoPath ?? '';
    if (path.isNotEmpty && _userPhotoFileExists) {
      image = photoImage(path);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      backgroundImage: image,
      child: image == null
          ? Icon(Icons.person, color: iconColor, size: iconSize)
          : null,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // F3: diagnostic — confirms resume fired without a process restart.
      // If a [App] main() log appears around this same moment, the
      // process was killed and the user just saw the splash screen.
      debugPrint('[Home] resumed (no process restart)');
      // Re-check when the app comes back to foreground (e.g. after overnight)
      _checkAllNotifications();
      _loadUnreadCount();
      // F1: refreshSession() removed — splash_screen.dart documents that
      // it can cause EXC_BAD_ACCESS native crashes with stale keychain
      // data. Calling it on every resume was killing the Flutter process,
      // and the OS was reopening the app from main() → SplashScreen,
      // making short context switches (WhatsApp, calculator) feel like
      // cold starts. The Supabase SDK auto-refreshes on API calls (sync,
      // realtime, queries), so we don't need to do it manually here.

      // Phase 19 — pull on resume. Android drops the realtime websocket
      // silently when backgrounded (battery management, Doze). Without
      // this pull, the sodero would come back to the foreground showing
      // stale data and have to close+reopen the app to see web edits.
      // pullOnOpen intentionally takes a full snapshot so bad/stale
      // watermarks from older builds cannot keep Android stuck on local
      // data. Fire-and-forget; the home screen's own DB-change listener
      // will rebuild affected views.
      if (!kDemoMode) {
        unawaited(SyncService.instance.pullOnOpen());
      }
    }
    // Persist recorrido state when app goes to background or is killed
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_db.flushPendingResumenLiveRecalcs());
      _persistRecorridoState();
    }
  }

  void _listenAuthState() {
    _authSub = AuthService.authStateChanges.listen((_) {});
  }

  /// Schedule a timer that fires at midnight (Argentina time) to re-check deuda notifications.
  void _scheduleMidnightCheck() {
    _midnightTimer?.cancel();
    final now = argentinaTime();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final untilMidnight = tomorrow.difference(now) + Duration(seconds: 5);
    _midnightTimer = Timer(untilMidnight, () {
      _checkAllNotifications();
      _loadUnreadCount();
      // Reset completed-today stats at midnight
      if ((_completedTodayDays.isNotEmpty ||
              _endedRecorridoDays.isNotEmpty ||
              _todayResumenId != null) &&
          mounted) {
        setState(() {
          _completedTodayDays.clear();
          _endedRecorridoDays.clear();
          _todayDuracion = 0;
          _liveClientesVisited = 0;
          _liveClientesTotal = 0;
          _liveProductosBought = 0;
          _liveRecaudado = 0;
          _liveDeudaTotal = 0;
          _ultimaVezRecaudado = 0;
          _ultimaVezDuracion = 0;
          _todayResumenId = null;
          _todayGastos = [];
        });
      }
      _scheduleMidnightCheck(); // schedule the next one
    });
  }

  bool _isEndedRecorridoEntry(Map<String, dynamic>? entry) {
    final endMillis = entry?['endMillis'];
    return endMillis != null && endMillis != 0;
  }

  DateTime _argDateFromEpochMillis(int millis) {
    return DateTime.fromMillisecondsSinceEpoch(
      millis,
    ).toUtc().subtract(const Duration(hours: 3));
  }

  String _fechaForActiveRecorrido(int repartoId) {
    // v85: scoped to the CURRENT vista's day — a resumed recorrido reuses
    // its stored start fecha; a sibling vista's recorrido must not bleed
    // its fecha into this context.
    final active = _configSelectedDay >= 0
        ? _activeRecorridos[_rkey(repartoId, _configSelectedDay)]
        : null;
    return active?.fecha ?? argTodayFecha();
  }

  String _semanaForActiveRecorrido(int repartoId) {
    final active = _configSelectedDay >= 0
        ? _activeRecorridos[_rkey(repartoId, _configSelectedDay)]
        : null;
    return active?.semana ?? _currentWeekString();
  }

  Future<Duration> _computeRepartoPastSessions(
    int repartoId,
    String fecha,
    String semana,
    int day,
  ) async {
    final resumen = await _db.getOrCreateTodayResumen(
      repartoId: repartoId,
      fecha: fecha,
      semana: semana,
      diaSemana: day,
    );
    final rawSessions = await _db.getResumenSessionsJson(resumen.id);
    var pastTotalMs = 0;
    if (rawSessions.isNotEmpty && rawSessions != '[]') {
      for (final s in (jsonDecode(rawSessions) as List)) {
        final m = Map<String, dynamic>.from(s as Map);
        final startMillis = m['startMillis'] as int?;
        final endMillis = m['endMillis'] as int?;
        if (startMillis != null &&
            endMillis != null &&
            endMillis > startMillis) {
          pastTotalMs += endMillis - startMillis;
        }
      }
    }
    return Duration(milliseconds: pastTotalMs);
  }

  void _startRecorrido() {
    unawaited(_startRecorridoAsync());
  }

  Future<void> _startRecorridoAsync() async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    final repartoId = _activeReparto?.id;
    if (repartoId == null) return;
    final myInstanceId = _currentInstanceIdFor(repartoId);
    final existing = await _db.getActiveRecorridoForRepartoAndDay(
      repartoId,
      _configSelectedDay,
    );
    // v85: this (reparto, day) is ALREADY RUNNING — started by another
    // vista or another phone (recorrido state syncs now). There is one
    // recorrido per (reparto, day), ever: ADOPT the running session
    // instead of restarting it (a fresh start would reset the sibling's
    // chronometer and re-key the day's fecha).
    if (existing != null && !_isEndedRecorridoEntry(existing)) {
      final entryDay = (existing['day'] as int?) ?? _configSelectedDay;
      final startMillis =
          (existing['startMillis'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;
      final startArg = _argDateFromEpochMillis(startMillis);
      final fecha = (existing['fecha'] as String?) ?? argFecha(startArg);
      final semana =
          (existing['semana'] as String?) ?? argentinaWeekString(at: startArg);
      final ownerInstanceId =
          (existing['instanceId'] as String?) ?? _defaultInstanceId(repartoId);
      final pastAccum = await _computeRepartoPastSessions(
        repartoId,
        fecha,
        semana,
        entryDay,
      );
      if (!mounted) return;
      setState(() {
        // First-owner wins the attribution — we join their session.
        _activeRecorridos[_rkey(repartoId, entryDay)] = _RecorridoState(
          start: DateTime.fromMillisecondsSinceEpoch(startMillis),
          fecha: fecha,
          semana: semana,
          day: entryDay,
          instanceId: ownerInstanceId,
          pastSessionsAccumulated: pastAccum,
        );
        _configSelectedDay = entryDay;
        _repartoConfirmed = true;
        _endedRecorridoDays[repartoId]?.remove(entryDay);
        if (_endedRecorridoDays[repartoId]?.isEmpty ?? false) {
          _endedRecorridoDays.remove(repartoId);
        }
        _currentIndex = 1;
      });
      _loadUltimaVez();
      await _ensureTodayResumen();
      _ensureChronoTimer();
      _startRecorridoNotification();
      TutorialController.instance.onRecorridoStarted();
      return;
    }
    if (_isEndedRecorridoEntry(existing)) {
      final entryDay = existing?['day'] as int?;
      if (entryDay == null || entryDay != _configSelectedDay) {
        // Wrong day configured; fall through to the fresh-start branch.
      } else {
        // Real epoch only — argentinaTime() returns a DateTime whose
        // millisecondsSinceEpoch is shifted by −3h vs DateTime.now(), so
        // persisting it as a startMillis corrupts every diff and clock
        // render. Reserve argentinaTime() for calendar/date labels.
        final now = DateTime.now();
        final argNow = argentinaTime();
        final fecha = (existing?['fecha'] as String?) ?? argFecha(argNow);
        final semana =
            (existing?['semana'] as String?) ?? argentinaWeekString(at: argNow);
        final resumedInstanceId =
            (existing?['instanceId'] as String?) ?? myInstanceId;
        final pastAccum = await _computeRepartoPastSessions(
          repartoId,
          fecha,
          semana,
          entryDay,
        );
        final nowMs = now.millisecondsSinceEpoch;
        await _db.reactivateRecorridoSession(repartoId, entryDay, nowMs);
        if (!mounted) return;
        setState(() {
          _activeRecorridos[_rkey(repartoId, entryDay)] = _RecorridoState(
            start: now,
            fecha: fecha,
            semana: semana,
            day: entryDay,
            instanceId: resumedInstanceId,
            pastSessionsAccumulated: pastAccum,
          );
          _configSelectedDay = entryDay;
          _repartoConfirmed = true;
          _endedRecorridoDays[repartoId]?.remove(entryDay);
          if (_endedRecorridoDays[repartoId]?.isEmpty ?? false) {
            _endedRecorridoDays.remove(repartoId);
          }
          _currentIndex = 1;
        });
        _loadUltimaVez();
        await _ensureTodayResumen();
        _ensureChronoTimer();
        _startRecorridoNotification();
        TutorialController.instance.onRecorridoStarted();
        return;
      }
    }
    // Switch to Ruta in the SAME setState that flips _activeRecorridos.
    // Doing it via post-frame caused the user to see one frame of the
    // running-hero on Inicio before being whisked to Ruta — looked
    // glitchy. Single-frame transition keeps the Inicio swap offscreen.
    final start = DateTime.now();
    final startArg = argentinaTime();
    final fecha = argFecha(startArg);
    final semana = argentinaWeekString(at: startArg);
    setState(() {
      _activeRecorridos[_rkey(repartoId, _configSelectedDay)] = _RecorridoState(
        start: start,
        fecha: fecha,
        semana: semana,
        day: _configSelectedDay,
        instanceId: myInstanceId,
      );
      _endedRecorridoDays[repartoId]?.remove(_configSelectedDay);
      if (_endedRecorridoDays[repartoId]?.isEmpty ?? false) {
        _endedRecorridoDays.remove(repartoId);
      }
      _currentIndex = 1;
    });
    _loadUltimaVez();
    _ensureTodayResumen();
    _persistRecorridoState();
    _ensureChronoTimer();
    _startRecorridoNotification();
    TutorialController.instance.onRecorridoStarted();
  }

  /// Ensure the global chronometer timer is running (shared across all recorridos).
  void _ensureChronoTimer() {
    if (_chronoTimer != null && _chronoTimer!.isActive) return;
    _chronoTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (_activeRecorridos.isNotEmpty && mounted) {
        setState(() {}); // triggers rebuild so _currentElapsed recalculates
      }
    });
  }

  // ─── Lock-screen "recorrido en curso" notification (Android only) ───
  // The notification mirrors the focused reparto's recorrido. The chronometer
  // base = start - pastSessionsAccumulated so it shows cumulative elapsed (same
  // math as `_currentElapsed`). Progress = the live visited/total stats.

  int _recorridoNotifBaseMillis(_RecorridoState s) =>
      s.start.millisecondsSinceEpoch - s.pastSessionsAccumulated.inMilliseconds;

  /// The recorrido the single ongoing notification should mirror: the
  /// current vista's, else (v85) any other running day of the active
  /// reparto, else any running recorrido at all — so finalizing one vista
  /// while another keeps running never leaves a stale notification.
  _RecorridoState? _notificationTargetRecorrido() {
    final current = _currentRecorrido;
    if (current != null) return current;
    final repartoId = _activeReparto?.id;
    if (repartoId != null) {
      for (final s in _recorridosForReparto(repartoId)) {
        return s;
      }
    }
    return _activeRecorridos.values.isEmpty
        ? null
        : _activeRecorridos.values.first;
  }

  /// (Re)show the ongoing notification for the focused recorrido.
  /// Best-effort, Android-only; a no-op when there's no recorrido in focus.
  void _startRecorridoNotification() {
    final reparto = _activeReparto;
    if (reparto == null) return;
    final s = _notificationTargetRecorrido();
    if (s == null) return;
    RecorridoNotificationService.instance.ensureNotificationPermission();
    RecorridoNotificationService.instance.start(
      baseWhenMillis: _recorridoNotifBaseMillis(s),
      repartoNombre: reparto.nombre,
      visited: _liveClientesVisited,
      total: _liveClientesTotal,
    );
  }

  /// Refresh the notification's progress (called as deliveries are recorded).
  void _refreshRecorridoNotification() {
    final reparto = _activeReparto;
    if (reparto == null) return;
    final s = _notificationTargetRecorrido();
    if (s == null) return;
    RecorridoNotificationService.instance.update(
      visited: _liveClientesVisited,
      total: _liveClientesTotal,
      repartoNombre: reparto.nombre,
      baseWhenMillis: _recorridoNotifBaseMillis(s),
    );
  }

  /// Tear down the notification if no recorrido remains, else refresh it.
  void _syncRecorridoNotificationOnEnd() {
    if (_activeRecorridos.isEmpty) {
      RecorridoNotificationService.instance.stop();
    } else {
      _startRecorridoNotification();
    }
  }

  /// "Terminar" tapped on the notification → run the normal end flow on Inicio.
  void _onNotificationTerminar() {
    if (!mounted) return;
    if (!_anyRecorridoActive) return;
    // v85: the notification mirrors _notificationTargetRecorrido, which
    // may be a DIFFERENT vista's day than the one currently focused.
    // Focus that day first so the confirm dialog + cierre act on the
    // recorrido the user is actually trying to end.
    final target = _notificationTargetRecorrido();
    if (target != null &&
        (_configSelectedDay != target.day || _currentRecorrido == null)) {
      final repartoId = _activeReparto?.id;
      if (repartoId != null &&
          _activeRecorridos.containsKey(_rkey(repartoId, target.day))) {
        setState(() {
          _configSelectedDay = target.day;
          _repartoConfirmed = true;
        });
        _loadConfigCarga();
        _loadUltimaVez();
        _ensureTodayResumen();
      }
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
    _confirmEndRecorrido();
  }

  void _confirmEndRecorrido() {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    // Block if any deferred (Saltar) client has a payment registered
    if (_hasDeferredWithPayment) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'No se puede terminar',
            style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Hay clientes marcados como "Saltar" que tienen un pago registrado. Volvé a atenderlos o quitales el pago antes de terminar.',
            style: TextStyle(color: tokens.textSub),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Entendido',
                style: TextStyle(
                  color: tokens.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // Check for unattended clients (pending or deferred)
    final unattended = _liveClientesTotal - _liveClientesVisited;
    final hasUnattended = unattended > 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Terminar recorrido?',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          hasUnattended
              ? 'Llevás ${_formatDuration(_currentElapsed)} de recorrido.\n\nTenés $unattended cliente${unattended == 1 ? '' : 's'} sin atender.'
              : 'Llevás ${_formatDuration(_currentElapsed)} de recorrido.',
          style: TextStyle(color: tokens.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showCierreSummary();
            },
            child: Text(
              'Terminar',
              style: TextStyle(
                color: tokens.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCierreSummary() async {
    // Demo: con el flujo en vivo habilitado, el sodero puede cerrar el día
    // (el recorrido ya es funcional). getOrCreateTodayResumen escribe en la
    // DB local del demo, que se reseedea en cada arranque.
    if (kDemoMode && !kDemoAllowLiveFlow) return;
    final repartoId = _activeReparto?.id;
    if (repartoId == null) return;

    // v85: the cierre closes the CURRENT vista's (reparto, day) recorrido
    // only — a sibling vista's running day is untouched.
    final recorridoState = _currentRecorrido;
    if (recorridoState == null) return;
    final duration = DateTime.now().difference(recorridoState.start);

    final semana = recorridoState.semana;
    final day = recorridoState.day;
    final fecha = recorridoState.fecha;

    // Get pagos
    final pagos = await _db.getPagosForDay(repartoId, semana, day);
    double efectivo = 0;
    double transferencia = 0;
    double cuentaCorriente = 0;
    for (final p in pagos) {
      if (p.metodoPago == 'efectivo') {
        efectivo += p.monto;
      } else if (p.metodoPago == 'transferencia') {
        transferencia += p.monto;
      } else if (p.metodoPago == 'no_pago') {
        cuentaCorriente += p.monto;
      }
    }

    // Get products balance: salida (carga) vs recibido (entregado) vs perdido (devuelto)
    final allProducts = await _db.getAllProducts(repartoId);
    final cargaData = await _db.getCargaForDayWithRemanente(
      repartoId,
      day,
      semana,
    );
    final productPackSizes = await _db.getProductoPackSizesForReparto(
      repartoId,
    );
    final carga = {for (final e in cargaData.entries) e.key: e.value.cantidad};
    // remanente is stored in PACKS; convert to units so it matches `carga`
    // (units) and the cierre/resumen balance math (teor = sal − ret, all units).
    final remanente = {
      for (final e in cargaData.entries)
        e.key: e.value.remanente * (productPackSizes[e.key] ?? 1),
    };
    // Aggregate entregas per product via single grouped query. Aggregates off
    // the entrega rows directly (not via current cliente.dia_semana), so a
    // cliente moved to a different day after being served still counts toward
    // their original day's totals.
    final aggregated = await _db.getEntregasAggregatedForDay(
      repartoId,
      semana,
      day,
    );
    final totalEntregado = {
      for (final e in aggregated.entries) e.key: e.value.entregado,
    };
    final totalDevuelto = {
      for (final e in aggregated.entries) e.key: e.value.devuelto,
    };

    if (!mounted) return;

    // Ensure the resumen exists for the day this recorrido started, even if
    // cierre happens after midnight.
    final resumen = await _db.getOrCreateTodayResumen(
      repartoId: repartoId,
      fecha: fecha,
      semana: semana,
      diaSemana: day,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CierreScreen(
          repartoId: repartoId,
          repartoNombre: _activeReparto!.nombre,
          duration: duration,
          efectivo: efectivo,
          transferencia: transferencia,
          cuentaCorriente: cuentaCorriente,
          allProducts: allProducts,
          carga: carga,
          remanente: remanente,
          totalEntregado: totalEntregado,
          totalDevuelto: totalDevuelto,
          productPackSizes: productPackSizes,
          semana: semana,
          diaSemana: day,
          resumenId: resumen.id,
          existingGastos: _allGastos,
          onFinalize: () async {
            final startMs = recorridoState.start.millisecondsSinceEpoch;
            final endMs = DateTime.now().millisecondsSinceEpoch;
            setState(() {
              _activeRecorridos.remove(_rkey(repartoId, recorridoState.day));
              _endedRecorridoDays[repartoId]?.remove(recorridoState.day);
              if (_endedRecorridoDays[repartoId]?.isEmpty ?? false) {
                _endedRecorridoDays.remove(repartoId);
              }
              _currentIndex = 0;
              // Keep stats visible until midnight
              _completedTodayDays
                  .putIfAbsent(repartoId, () => <int>{})
                  .add(recorridoState.day);
              _hasDeferredWithPayment = false;
              _todayResumenId = null;
              _todayGastos = [];
            });
            // Stop timer if no more active recorridos
            if (_activeRecorridos.isEmpty) {
              _chronoTimer?.cancel();
              _chronoTimer = null;
            }
            // Clear (or refresh) the lock-screen recorrido notification.
            _syncRecorridoNotificationOnEnd();
            await _db.appendResumenSession(
              resumenId: resumen.id,
              startMillis: startMs,
              endMillis: endMs,
            );
            await _db.markRecorridoSessionEnded(
              repartoId,
              recorridoState.day,
              endMs,
            );
            await _db.clearRecorridoForRepartoAndDay(
              repartoId,
              recorridoState.day,
            );
            _loadUltimaVez();
          },
        ),
      ),
    );
  }

  void _onStatsChanged(
    int clientesVisited,
    int clientesTotal,
    int productosBought,
    double recaudado,
    double deudaTotal,
    bool hasDeferredWithPayment,
  ) {
    if (mounted) {
      setState(() {
        _liveClientesVisited = clientesVisited;
        _liveClientesTotal = clientesTotal;
        _liveProductosBought = productosBought;
        _liveRecaudado = recaudado;
        _liveDeudaTotal = deudaTotal;
        _hasDeferredWithPayment = hasDeferredWithPayment;
      });
      // Keep the lock-screen notification's progress bar in sync.
      if (_anyRecorridoActive) _refreshRecorridoNotification();
    }
  }

  Future<void> _ensureTodayResumen() async {
    debugPrint(
      '[HOME] _ensureTodayResumen called: reparto=${_activeReparto?.id}, day=$_configSelectedDay',
    );
    if (_activeReparto == null || _configSelectedDay < 0) {
      debugPrint(
        '[HOME] _ensureTodayResumen SKIPPED: reparto=${_activeReparto?.id}, day=$_configSelectedDay',
      );
      return;
    }
    final repartoId = _activeReparto!.id;
    final fecha = _fechaForActiveRecorrido(repartoId);
    final semana = _semanaForActiveRecorrido(repartoId);
    final resumen = await _db.getOrCreateTodayResumen(
      repartoId: repartoId,
      fecha: fecha,
      semana: semana,
      diaSemana: _configSelectedDay,
    );
    debugPrint(
      '[HOME] Resumen created/found: id=${resumen.id}, fecha=${resumen.fecha}',
    );
    if (mounted) {
      setState(() {
        _todayResumenId = resumen.id;
        // Load only manual gastos — product gastos are recomputed from current carga
        final allSaved = resumen.gastosJson.isNotEmpty
            ? List<Map<String, dynamic>>.from(
                (jsonDecode(resumen.gastosJson) as List).map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ),
              )
            : <Map<String, dynamic>>[];
        _todayGastos = allSaved.where((g) => g['type'] != 'producto').toList();
      });
    }
  }

  Future<void> _saveTodayGastos() async {
    // Lazily create resumen if user is adding gastos before starting recorrido
    if (_todayResumenId == null) {
      // Save current gastos before _ensureTodayResumen overwrites them
      final pendingGastos = List<Map<String, dynamic>>.from(_todayGastos);
      await _ensureTodayResumen();
      // Restore the pending gastos (ensureTodayResumen resets them from empty DB)
      if (pendingGastos.isNotEmpty) {
        setState(() => _todayGastos = pendingGastos);
      }
    }
    if (_todayResumenId == null) {
      debugPrint(
        '[HOME] _saveTodayGastos: resumenId still null after ensure, aborting',
      );
      return;
    }
    final allGastos = _allGastos;
    final gastosJson = jsonEncode(allGastos);
    // Dedupe: skip the DB write (and the onDataChanged fan-out it
    // triggers) when the value hasn't changed for this resumen. Without
    // this guard, the listener-driven _loadConfigCarga → _saveTodayGastos
    // chain hard-loops at the 300ms debounce cadence the moment
    // _todayResumenId is non-null.
    if (_todayResumenId == _lastSavedGastosResumenId &&
        gastosJson == _lastSavedGastosJson) {
      return;
    }
    double total = 0;
    for (final g in allGastos) {
      total += ((g['monto'] as num?)?.toDouble() ?? 0);
    }
    debugPrint(
      '[HOME] _saveTodayGastos: saving ${allGastos.length} gastos (total=$total) to resumen $_todayResumenId',
    );
    await _db.updateResumenGastos(_todayResumenId!, total, gastosJson);
    _lastSavedGastosJson = gastosJson;
    _lastSavedGastosResumenId = _todayResumenId;
  }

  Future<void> _loadUltimaVez() async {
    if (_activeReparto == null || _configSelectedDay < 0) return;
    final todayFecha = _fechaForActiveRecorrido(_activeReparto!.id);

    // Get the last finalized resumen for the same day-of-week, excluding today
    final lastResumen = await _db.getLastResumenForDay(
      _activeReparto!.id,
      _configSelectedDay,
      excludeFecha: todayFecha,
    );
    // Also check if today has a finalized resumen
    final todayResumen = await _db.getResumenForDate(
      repartoId: _activeReparto!.id,
      fecha: todayFecha,
      diaSemana: _configSelectedDay,
    );

    if (!mounted) return;
    setState(() {
      _ultimaVezRecaudado = lastResumen != null
          ? lastResumen.efectivo + lastResumen.transferencia
          : 0;
      _ultimaVezDuracion = lastResumen?.duracionSegundos ?? 0;
      _todayDuracion =
          (todayResumen != null && todayResumen.duracionSegundos > 0)
          ? todayResumen.duracionSegundos
          : 0;
      if (_todayDuracion > 0 && _activeReparto != null) {
        _completedTodayDays
            .putIfAbsent(_activeReparto!.id, () => <int>{})
            .add(_configSelectedDay);
      }
    });
  }

  /// Persist all active recorrido states to DB so they survive app kill.
  /// Reads the existing JSON first to preserve `clientStatuses` written by
  /// RutaScreen via saveRecorridoClientStatuses — otherwise lifecycle saves
  /// here would clobber 'saltado' (deferred) statuses that have no pago
  /// fallback to restore from.
  ///
  /// v85: the array is no longer "ours" alone — it can hold entries from
  /// other vistas/phones (merged in by sync) and cleared soft-tombstones.
  /// Everything we don't own in memory is passed through VERBATIM, and
  /// `lastTouchMs` is stamped only when OUR entry's scalars actually
  /// changed — a lifecycle save of unchanged state must not out-arbitrate
  /// a sibling phone's fresher end/reactivate in the merge.
  Future<void> _persistRecorridoState() async {
    if (_activeRecorridos.isEmpty) return;
    await _db.mutateActiveRecorridosAtomic((existing) {
      final existingByKey = <String, Map<String, dynamic>>{
        for (final e in existing)
          if (e['repartoId'] is int && e['day'] is int)
            '${e['repartoId']}:${e['day']}': e,
      };
      final activeKeyed = <String, Map<String, dynamic>>{};
      for (final e in _activeRecorridos.entries) {
        final s = e.value;
        final key = e.key; // already '$repartoId:$day'
        final prior = existingByKey[key];
        final priorCleared = prior != null && prior['cleared'] == true;
        final startMs = s.start.millisecondsSinceEpoch;
        final changed =
            prior == null ||
            priorCleared ||
            (prior['startMillis'] as num?)?.toInt() != startMs ||
            _isEndedRecorridoEntry(prior) ||
            prior['fecha'] != s.fecha ||
            prior['semana'] != s.semana;
        activeKeyed[key] = {
          'repartoId': int.parse(key.split(':').first),
          'startMillis': startMs,
          'fecha': s.fecha,
          'semana': s.semana,
          'day': s.day,
          'clientStatuses':
              (priorCleared ? null : prior?['clientStatuses'] as String?) ?? '',
          'instanceId':
              (priorCleared ? null : prior?['instanceId'] as String?) ??
              s.instanceId,
          if (!priorCleared && prior?['statusTouchMs'] != null)
            'statusTouchMs': prior?['statusTouchMs'],
          'lastTouchMs': changed
              ? LogicalClock.nextMs()
              // `changed` is true whenever prior == null → promoted here.
              : ((prior['lastTouchMs'] as num?)?.toInt() ?? startMs),
        };
      }
      final list = <Map<String, dynamic>>[...activeKeyed.values];
      for (final entry in existing) {
        final repartoId = entry['repartoId'] as int?;
        final day = entry['day'] as int?;
        if (repartoId == null || day == null) continue;
        final key = '$repartoId:$day';
        if (activeKeyed.containsKey(key)) continue;
        // Pass-through: ended entries (resume affordance), other vistas'/
        // phones' running days, and cleared tombstones all survive.
        list.add(entry);
      }
      return list;
    });
  }

  /// Restore previously active recorridos after app restart.
  Future<void> _restoreRecorrido() async {
    try {
      // First try new multi-recorrido format
      final savedList = await _db.getActiveRecorridos();
      if (savedList.isNotEmpty) {
        await _restoreMultiRecorridos(savedList);
        return;
      }
      // Fallback: try legacy single-recorrido format
      final legacy = await _db.getRecorridoState();
      if (legacy != null) {
        await _restoreMultiRecorridos([legacy]);
        await _db.clearRecorridoState(); // migrate away from legacy
      }
    } catch (e) {
      debugPrint('[HOME] Failed to restore recorridos: $e');
      _db.clearAllRecorridos();
    }
  }

  Future<void> _restoreMultiRecorridos(
    List<Map<String, dynamic>> savedList,
  ) async {
    bool anyRestored = false;
    int? firstRestoredRepartoId;

    for (final saved in savedList) {
      final startMillis = saved['startMillis'] as int;
      final repartoId = saved['repartoId'] as int;
      final day = saved['day'] as int;
      final start = DateTime.fromMillisecondsSinceEpoch(startMillis);
      final ended = _isEndedRecorridoEntry(saved);

      // Verify the reparto still exists
      if (!_repartos.any((r) => r.id == repartoId)) continue;

      if (ended) {
        _endedRecorridoDays.putIfAbsent(repartoId, () => <int>{}).add(day);
        continue;
      }

      final startArg = _argDateFromEpochMillis(startMillis);
      final fecha = (saved['fecha'] as String?) ?? argFecha(startArg);
      final semana =
          (saved['semana'] as String?) ?? argentinaWeekString(at: startArg);
      final instanceId =
          (saved['instanceId'] as String?) ?? _defaultInstanceId(repartoId);
      final pastAccum = await _computeRepartoPastSessions(
        repartoId,
        fecha,
        semana,
        day,
      );
      _activeRecorridos[_rkey(repartoId, day)] = _RecorridoState(
        start: start,
        fecha: fecha,
        semana: semana,
        day: day,
        instanceId: instanceId,
        pastSessionsAccumulated: pastAccum,
      );
      if (!anyRestored) {
        firstRestoredRepartoId = repartoId;
        anyRestored = true;
      }
    }

    if (!anyRestored || !mounted) {
      if (mounted && _endedRecorridoDays.isNotEmpty) {
        setState(() {});
      }
      return;
    }

    // Switch to the first restored recorrido's reparto. v85: prefer the
    // recorrido owned by this device's CURRENT vista of that reparto, so a
    // phone that was running «Feriado» doesn't wake up focused on the
    // default vista's day; fall back to the first restored entry and adopt
    // its vista as current.
    final restoredOfReparto = _recorridosForReparto(
      firstRestoredRepartoId!,
    ).toList();
    final preferredInstanceId = _currentInstanceIdFor(firstRestoredRepartoId);
    final focus = restoredOfReparto.firstWhere(
      (s) => s.instanceId == preferredInstanceId,
      orElse: () => restoredOfReparto.first,
    );
    if (focus.instanceId != preferredInstanceId) {
      await _setCurrentInstancePointer(
        firstRestoredRepartoId,
        focus.instanceId,
      );
    }
    setState(() {
      _activeReparto = _repartos.firstWhere(
        (r) => r.id == firstRestoredRepartoId,
      );
      _configSelectedDay = focus.day;
      _repartoConfirmed = true;
      _currentIndex = 1;
    });

    _loadUltimaVez();
    _ensureTodayResumen();
    _loadConfigCarga();
    _persistRecorridoState(); // re-save in new format

    // Start the shared chronometer
    _ensureChronoTimer();
    // Re-show the lock-screen notification for the restored recorrido.
    _startRecorridoNotification();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _initLocale() async {
    await initializeDateFormatting('es_AR', null);
    setState(() => _localeInitialized = true);
  }

  Future<void> _loadUserName() async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) return;
      final data = await _db.getCuentaLocal(userId);
      final name = data?['nombre'] as String?;
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _userName = name);
      }
    } catch (_) {}
  }

  Future<void> _loadWorkDays() async {
    final days = await _db.getWorkDays();
    bool selectedDayChanged = false;
    if (mounted) {
      setState(() {
        _workDays = days;
        // If a day WAS picked but the user just removed it from work days in
        // Configuración, clear the selection so the sodero is forced to pick
        // again. We never auto-select a day on cold start (Phase 3 rule).
        if (_configSelectedDay >= 0 && !days.contains(_configSelectedDay)) {
          _configSelectedDay = -1;
          selectedDayChanged = true;
        }
      });
    }
    // P1.3: if the selected day moved, reload the config carga summary so
    // Inicio doesn't display Wednesday's stock under the new Thursday
    // label (or worse, an empty stock under a day-that-just-disappeared).
    if (selectedDayChanged) {
      await _loadConfigCarga();
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final unread = await _db.getUnreadNotifications();
      if (mounted) setState(() => _unreadNotifCount = unread.length);
    } catch (_) {}
  }

  /// Run all notification checks.
  Future<void> _checkAllNotifications() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;

    try {
      final repartos = await _db.getRepartosForUser(userId);
      for (final reparto in repartos) {
        final allClients = await _db.getClientesForReparto(reparto.id);
        await _checkDeudaNotifications(reparto.id, allClients);
        await _checkInactiveNotifications(reparto.id, allClients);
      }
      await _loadUnreadCount();
    } catch (_) {}
  }

  /// Deuda notification: client owes money for X+ consecutive weeks.
  Future<void> _checkDeudaNotifications(
    int repartoId,
    List<Cliente> clients,
  ) async {
    final enabled = await _db.getDeudaNotifEnabled();
    if (!enabled) return;
    final weeks = await _db.getDeudaNotifWeeks();
    final thresholdDays = weeks * 7;

    for (final client in clients) {
      final allEntregas = await _db.getAllEntregasForClient(
        client.id,
        repartoId,
      );
      final allPagos = await _db.getAllPagosForClient(client.id, repartoId);

      double totalOwed = 0;
      double totalPaid = 0;
      for (final e in allEntregas) {
        if (e.entregado <= 0) continue;
        final precio = e.precioUnitario > 0
            ? e.precioUnitario
            : await _db.getEffectivePrice(client.id, e.productoId);
        totalOwed += e.entregado * precio;
      }
      const nonPaymentMetodos = {'no_pago', 'no_compro', 'ausente', 'saltado'};
      for (final p in allPagos) {
        if (nonPaymentMetodos.contains(p.metodoPago)) continue;
        totalPaid += p.monto;
      }

      final deuda = totalOwed - totalPaid;

      if (deuda <= 0) {
        await _db.clearNotifDismissal(client.id, 'deuda_weeks');
        continue;
      }

      if (await _db.hasDeudaNotification(client.id)) continue;
      if (await _db.isNotifDismissed(client.id, 'deuda_weeks')) continue;

      final events = <Map<String, dynamic>>[];
      for (final e in allEntregas) {
        if (e.entregado <= 0) continue;
        final precio = e.precioUnitario > 0
            ? e.precioUnitario
            : await _db.getEffectivePrice(client.id, e.productoId);
        events.add({
          'semana': e.semana,
          'dia': e.diaSemana,
          'delta': -e.entregado * precio,
        });
      }
      for (final p in allPagos) {
        if (nonPaymentMetodos.contains(p.metodoPago)) continue;
        events.add({'semana': p.semana, 'dia': p.diaSemana, 'delta': p.monto});
      }
      events.sort((a, b) {
        final cmp = (a['semana'] as String).compareTo(b['semana'] as String);
        return cmp != 0 ? cmp : (a['dia'] as int).compareTo(b['dia'] as int);
      });

      double balance = 0;
      String? firstNegativeSemana;
      int? firstNegativeDia;
      for (final ev in events) {
        balance += ev['delta'] as double;
        if (balance >= 0) {
          firstNegativeSemana = null;
          firstNegativeDia = null;
        } else if (firstNegativeSemana == null) {
          firstNegativeSemana = ev['semana'] as String;
          firstNegativeDia = ev['dia'] as int;
        }
      }
      if (firstNegativeSemana == null) continue;

      DateTime earliestDeudaDate;
      try {
        final parts = firstNegativeSemana.split('-W');
        final year = int.parse(parts[0]);
        final week = int.parse(parts[1]);
        final jan1 = DateTime(year, 1, 1);
        earliestDeudaDate = jan1.add(
          Duration(days: (week - 1) * 7 + firstNegativeDia!),
        );
      } catch (_) {
        continue;
      }

      final daysSince = DateTime.now().difference(earliestDeudaDate).inDays;
      if (daysSince >= thresholdDays) {
        await _db.addNotification(
          type: 'deuda_weeks',
          title: 'Deuda prolongada',
          body: '${client.nombre} tiene deuda hace $weeks+ semanas.',
          clienteId: client.id,
        );
      }
    }
  }

  /// Inactive notification: client hasn't bought anything in X+ consecutive weeks.
  /// Detected by checking that all entregas in the last X weeks have entregado == 0
  /// (or no entregas at all).
  Future<void> _checkInactiveNotifications(
    int repartoId,
    List<Cliente> clients,
  ) async {
    final enabled = await _db.getInactiveNotifEnabled();
    if (!enabled) return;
    final weeks = await _db.getInactiveNotifWeeks();
    final thresholdDays = weeks * 7;
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: thresholdDays));

    for (final client in clients) {
      // Skip clients based on their frequency — they naturally buy less often
      if (client.frecuencia == 'mensual') continue;
      if (weeks <= 2 && client.frecuencia == 'quincenal') continue;

      final allEntregas = await _db.getAllEntregasForClient(
        client.id,
        repartoId,
      );

      // Check if client has ANY purchase (entregado > 0) in the last X weeks
      bool boughtRecently = false;
      for (final e in allEntregas) {
        if (e.entregado <= 0) continue;
        // Parse week to approximate date
        try {
          final parts = e.semana.split('-W');
          final year = int.parse(parts[0]);
          final week = int.parse(parts[1]);
          final jan1 = DateTime(year, 1, 1);
          final entregaDate = jan1.add(
            Duration(days: (week - 1) * 7 + e.diaSemana),
          );
          if (entregaDate.isAfter(cutoff)) {
            boughtRecently = true;
            break;
          }
        } catch (_) {}
      }

      if (boughtRecently) {
        // Client bought recently — clear dismissal so cycle can restart
        await _db.clearNotifDismissal(client.id, 'inactive_weeks');
        continue;
      }

      // Client hasn't bought in X weeks — but only notify if they have SOME history
      // (don't notify for brand-new clients with zero entregas)
      if (allEntregas.isEmpty) continue;

      // Check if already notified or dismissed
      if (await _db.hasNotificationForClient(client.id, 'inactive_weeks'))
        continue;
      if (await _db.isNotifDismissed(client.id, 'inactive_weeks')) continue;

      await _db.addNotification(
        type: 'inactive_weeks',
        title: 'Cliente inactivo',
        body: '${client.nombre} no compra hace $weeks+ semanas.',
        clienteId: client.id,
      );
    }
  }

  Future<void> _loadRepartos() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    final list = await _db.getRepartosForUser(userId);
    if (mounted) {
      setState(() {
        _repartos = list;
        // Keep current selection if still valid
        if (_activeReparto != null &&
            list.any((r) => r.id == _activeReparto!.id)) {
          _activeReparto = list.firstWhere((r) => r.id == _activeReparto!.id);
        } else if (list.isNotEmpty) {
          // Try to restore last selected reparto
          _restoreLastReparto(list);
        } else {
          _activeReparto = null;
        }
      });
      _loadProductRanking();
      _loadConfigCarga();
    }
  }

  Future<void> _restoreLastReparto(List<Reparto> list) async {
    final lastId = await _db.getLastRepartoId();
    if (lastId != null && list.any((r) => r.id == lastId)) {
      if (mounted)
        setState(() => _activeReparto = list.firstWhere((r) => r.id == lastId));
    } else if (list.isNotEmpty) {
      if (mounted) setState(() => _activeReparto = list.first);
    }
  }

  Future<void> _loadProductRanking() async {
    final repartoId = _activeReparto?.id;
    if (repartoId == null) return;

    final allProducts = await _db.getAllProductsIncludingDeleted(repartoId);
    final allEntregas = await _db.getAllEntregasForReparto(repartoId);

    // Filter entregas to current month only
    final now = argentinaTime();
    final currentYear = now.year;
    final currentMonth = now.month;
    final monthEntregas = allEntregas.where((e) {
      final date = _weekStringToDate(e.semana, e.diaSemana);
      return date != null &&
          date.year == currentYear &&
          date.month == currentMonth;
    });

    // Aggregate total entregado per product + monthly counters (days
    // active, total units, unique clientes, best day by units).
    final totals = <int, int>{};
    final activeDates = <String>{};
    final uniqueClientes = <int>{};
    final unitsPerDate = <String, int>{};
    final dateForKey = <String, DateTime>{};
    var totalUnits = 0;
    for (final e in monthEntregas) {
      // Cross-product aggregates stay in raw units; pack formatting is only
      // meaningful when rendering one product with one pack size.
      totals[e.productoId] = (totals[e.productoId] ?? 0) + e.entregado;
      if (e.entregado > 0) {
        final dateKey = '${e.semana}-${e.diaSemana}';
        activeDates.add(dateKey);
        uniqueClientes.add(e.clienteId);
        unitsPerDate[dateKey] = (unitsPerDate[dateKey] ?? 0) + e.entregado;
        if (!dateForKey.containsKey(dateKey)) {
          final d = _weekStringToDate(e.semana, e.diaSemana);
          if (d != null) dateForKey[dateKey] = d;
        }
        totalUnits += e.entregado;
      }
    }

    // Best day this month
    String? bestDayKey;
    var bestDayUnits = 0;
    unitsPerDate.forEach((k, v) {
      if (v > bestDayUnits) {
        bestDayUnits = v;
        bestDayKey = k;
      }
    });
    String? bestDayLabel;
    if (bestDayKey != null && dateForKey[bestDayKey] != null) {
      final d = dateForKey[bestDayKey]!;
      // d.weekday: Mon=1..Sun=7 → _allDayNames is 0-indexed Mon=0
      final dayShort = _allDayNames[d.weekday - 1].substring(0, 3);
      bestDayLabel = '$dayShort ${d.day}';
    }

    // Build ranked list sorted by quantity desc
    final ranked = allProducts.map((p) {
      return _RankedProduct(name: p.nombre, quantity: totals[p.id] ?? 0);
    }).toList()..sort((a, b) => b.quantity.compareTo(a.quantity));

    // Last 7 days unit tally (uses ALL entregas, not just current-month,
    // so a week spanning a month boundary renders correctly).
    final todayDate = argentinaTime();
    final todayMid = DateTime(todayDate.year, todayDate.month, todayDate.day);
    final last7 = List<int>.filled(7, 0);
    for (final e in allEntregas) {
      if (e.entregado <= 0) continue;
      final d = _weekStringToDate(e.semana, e.diaSemana);
      if (d == null) continue;
      final dMid = DateTime(d.year, d.month, d.day);
      final daysAgo = todayMid.difference(dMid).inDays;
      if (daysAgo < 0 || daysAgo >= 7) continue;
      last7[6 - daysAgo] += e.entregado;
    }

    if (mounted) {
      setState(() {
        _rankedProducts = ranked;
        _monthDaysActive = activeDates.length;
        _monthTotalUnits = totalUnits;
        _monthUniqueClientes = uniqueClientes.length;
        _monthBestDayUnits = bestDayUnits;
        _monthBestDayLabel = bestDayLabel;
        _last7DaysUnits = last7;
      });
    }
  }

  /// Convert a week string (e.g. "2026-W11") and diaSemana (0=Mon..6=Sun)
  /// to the actual date.
  DateTime? _weekStringToDate(String semana, int diaSemana) {
    final match = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(semana);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final week = int.parse(match.group(2)!);
    // Jan 4 is always in ISO week 1
    final jan4 = DateTime(year, 1, 4);
    final mondayOfWeek1 = jan4.subtract(Duration(days: jan4.weekday - 1));
    final monday = mondayOfWeek1.add(Duration(days: (week - 1) * 7));
    return monday.add(Duration(days: diaSemana));
  }

  Future<void> _createReparto(String nombre) async {
    if (blockDemoAction(context)) return;
    final userId = AuthService.currentUserId;
    if (userId == null) return;
    final tutorial = TutorialController.instance;
    final shouldCreateExampleClient =
        tutorial.current == GuidedStep.createReparto;
    final repartoId = await _db.createReparto(nombre, userId);
    final exampleClientId = shouldCreateExampleClient
        ? await _createTutorialExampleClient(repartoId)
        : null;
    await _loadRepartos();
    if (_repartos.isNotEmpty) {
      final created = _repartos.firstWhere(
        (r) => r.id == repartoId,
        orElse: () => _repartos.last,
      );
      setState(() => _activeReparto = created);
      _db.setLastRepartoId(created.id);
      tutorial.onRepartoCreated(created.id, exampleClientId: exampleClientId);
    }
  }

  Future<int> _createTutorialExampleClient(int repartoId) async {
    final clientId = await _db.createCliente(
      repartoId,
      _defaultTutorialClientDay(),
      'Cliente de ejemplo',
      direccion: 'Calle 1 123',
      telefono: '0000000000',
      frecuencia: 'semanal',
      etiqueta: 'Ejemplo',
      notas:
          'Cliente de ejemplo creado para practicar el tutorial. Podés editarlo o borrarlo después.',
    );
    await _db.updateCliente(clientId, showOnMap: false);
    return clientId;
  }

  int _defaultTutorialClientDay() {
    final todayIndex = argentinaTime().weekday - 1;
    if (_workDays.contains(todayIndex)) return todayIndex;
    return _workDays.isNotEmpty ? _workDays.first : 0;
  }

  Future<void> _showRepartoSelector() async {
    final rootContext = context;
    await showModalBottomSheet(
      context: context,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Seleccionar reparto',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // Existing repartos
                ..._repartos.map((reparto) {
                  final isActive = _activeReparto?.id == reparto.id;
                  return ListTile(
                    leading: Icon(
                      isActive
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isActive ? tokens.primaryBlue : tokens.textMuted,
                    ),
                    title: Text(
                      'Reparto: ${reparto.nombre}',
                      style: TextStyle(
                        color: tokens.text,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: tokens.danger,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDeleteReparto(reparto);
                      },
                    ),
                    onTap: () {
                      setState(() {
                        _activeReparto = reparto;
                        // v85: restore the context of this reparto's
                        // CURRENT vista — its running recorrido's day if
                        // it owns one, else its configured day.
                        final instId = _currentInstanceIdFor(reparto.id);
                        var day = -1;
                        for (final s in _recorridosForReparto(reparto.id)) {
                          if (s.instanceId == instId) {
                            day = s.day;
                            break;
                          }
                        }
                        if (day < 0) {
                          final cfg = (_instanceById(instId)?['day'] as num?)
                              ?.toInt();
                          if (cfg != null && cfg >= 0) day = cfg;
                        }
                        _configSelectedDay = day;
                        _repartoConfirmed = day >= 0;
                        if (day < 0) {
                          _todayResumenId = null;
                          _todayGastos = [];
                        }
                        _configExpanded = false;
                      });
                      _db.setLastRepartoId(reparto.id);
                      _loadConfigCarga();
                      _loadUltimaVez();
                      _ensureTodayResumen();
                      Navigator.pop(context);
                    },
                  );
                }),
                Divider(color: tokens.cardBorder, height: 1),
                // Create new reparto
                ListTile(
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: tokens.primaryBlue,
                  ),
                  title: Text(
                    'Crear nuevo reparto',
                    style: TextStyle(color: tokens.primaryBlue),
                  ),
                  onTap: () {
                    if (blockDemoAction(rootContext)) return;
                    Navigator.pop(context);
                    _showCreateRepartoDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteReparto(Reparto reparto) async {
    if (blockDemoAction(context)) return;
    // Round 1
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar reparto',
          style: TextStyle(
            color: tokens.text,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          '¿Eliminar "${reparto.nombre}"?\n\nSe borrarán todos los clientes, entregas, pagos, productos y resúmenes de este reparto.',
          style: TextStyle(color: tokens.textSub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Continuar',
              style: TextStyle(
                color: tokens.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    // Round 2
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Estás seguro?',
          style: TextStyle(
            color: tokens.danger,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Esta acción NO se puede deshacer. Todo el contenido de "${reparto.nombre}" se eliminará permanentemente.',
          style: TextStyle(color: tokens.textSub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar permanentemente',
              style: TextStyle(
                color: tokens.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    // Local delete writes a `repartos` tombstone (scoped to the signed-in
    // user) inside the same transaction. SyncService.deleteRepartoFromCloud
    // is the immediate happy-path call; if it fails or the device is
    // offline, _processPendingDeletions retries the cascade on the next
    // sync cycle, and the cloud restore loops skip tombstoned ids so the
    // reparto can't reappear.
    await _db.deleteReparto(reparto.id, userId: AuthService.currentUser?.id);
    SyncService.instance.deleteRepartoFromCloud(reparto.id);

    // Clean up recorridos (every day/vista) for the deleted reparto
    final deletedKeys = _activeRecorridos.keys
        .where((k) => k.startsWith('${reparto.id}:'))
        .toList();
    if (deletedKeys.isNotEmpty) {
      for (final k in deletedKeys) {
        _activeRecorridos.remove(k);
      }
      _db.clearRecorridoForReparto(reparto.id);
      if (_activeRecorridos.isEmpty) {
        _chronoTimer?.cancel();
        _chronoTimer = null;
      }
      _syncRecorridoNotificationOnEnd();
    } else {
      _db.clearRecorridoForReparto(reparto.id);
    }
    _completedTodayDays.remove(reparto.id);
    // v85: the reparto's vistas go with it (soft-deleted so peers don't
    // resurrect them) — the ONLY flow that removes every instance,
    // including the implicit default. Business data deletion is handled
    // by deleteReparto's tombstone cascade above, never by this.
    unawaited(_db.purgeInstancesForReparto(reparto.id));
    _currentInstancePointers.remove(reparto.id);
    unawaited(
      SharedPreferences.getInstance().then(
        (p) => p.remove('$_instancePrefPrefix${reparto.id}'),
      ),
    );

    // Switch to another reparto or clear
    await _loadRepartos();
    if (_repartos.isNotEmpty) {
      setState(() {
        _activeReparto = _repartos.first;
        final running = _recorridosForReparto(_repartos.first.id).toList();
        _repartoConfirmed = running.isNotEmpty;
        if (running.isNotEmpty) _configSelectedDay = running.first.day;
        _configExpanded = false;
      });
      _db.setLastRepartoId(_repartos.first.id);
    } else {
      setState(() {
        _activeReparto = null;
        _repartoConfirmed = false;
        _configExpanded = false;
      });
    }
  }

  void _showCreateRepartoDialog() {
    final controller = TextEditingController();
    final rootContext = context;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Nuevo reparto',
            style: TextStyle(color: tokens.text, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: tokens.text),
            decoration: InputDecoration(
              hintText: 'Nombre del reparto',
              hintStyle: TextStyle(color: tokens.textMuted),
              prefixText: 'Reparto: ',
              prefixStyle: TextStyle(color: tokens.textSub, fontSize: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: tokens.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: tokens.primaryBlue),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: tokens.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  if (blockDemoAction(rootContext)) return;
                  _createReparto(name);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  String _currentWeekString() => argentinaWeekString();

  bool _cargaMapsEqual(Map<int, int> a, Map<int, int> b) {
    // Compare only non-zero entries
    final aFiltered = {
      for (final e in a.entries)
        if (e.value > 0) e.key: e.value,
    };
    final bFiltered = {
      for (final e in b.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (aFiltered.length != bFiltered.length) return false;
    for (final key in aFiltered.keys) {
      if (aFiltered[key] != bFiltered[key]) return false;
    }
    return true;
  }

  Future<void> _loadConfigCargaAndCheckChanges() async {
    if (_activeReparto == null || _configSelectedDay < 0) return;
    final oldCarga = Map<int, int>.from(_configCarga);
    await _loadConfigCarga();
    if (_repartoConfirmed && !_cargaMapsEqual(oldCarga, _configCarga)) {
      setState(() => _repartoConfirmed = false);
    }
  }

  Future<void> _loadConfigCarga() async {
    if (_activeReparto == null || _configSelectedDay < 0) {
      setState(() {
        _configCarga = {};
        _configRemanente = {};
        _configProducts = [];
        _configPackSizes = {};
      });
      return;
    }
    final products = await _db.getAllProducts(_activeReparto!.id);
    final cargaData = await _db.getCargaForDayWithRemanente(
      _activeReparto!.id,
      _configSelectedDay,
      _semanaForActiveRecorrido(_activeReparto!.id),
    );
    final packSizes = await _db.getProductoPackSizesForReparto(
      _activeReparto!.id,
    );
    if (mounted) {
      setState(() {
        _configProducts = products;
        _configCarga = {
          for (final e in cargaData.entries) e.key: e.value.cantidad,
        };
        _configRemanente = {
          for (final e in cargaData.entries) e.key: e.value.remanente,
        };
        _configPackSizes = packSizes;
      });
      // Persist product gastos to resumen if one exists
      if (_todayResumenId != null) {
        _saveTodayGastos();
      }
    }
  }

  Future<void> _onCargaChanged(int diaSemana, String semana) async {
    // Carga edits are preparation work, not an Inicio day choice. If the
    // sodero has not explicitly selected this same day in Inicio, leave
    // SELECCIONAR DÍA untouched; otherwise returning from Carga creates a
    // "ghost" selected day with no confirmed resumen visible.
    if (_configSelectedDay < 0 || diaSemana != _configSelectedDay) {
      return;
    }
    await _loadConfigCarga();
    // Product gastos are recomputed via _productGastos getter; save to resumen
    await _saveTodayGastos();
  }

  String _formattedDate() {
    if (!_localeInitialized) return '';
    final now = argentinaTime();
    final dayName = DateFormat('EEEE', 'es_AR').format(now);
    final capitalized = dayName[0].toUpperCase() + dayName.substring(1);
    final dayNum = now.day;
    final month = DateFormat('MMMM', 'es_AR').format(now);
    final monthCap = month[0].toUpperCase() + month.substring(1);
    return '${capitalized.toUpperCase()}, $dayNum DE ${monthCap.toUpperCase()}';
  }

  Widget _wrapInicioGuided(Widget child) {
    // Always mounted (not gated on the Inicio tab): the host self-gates via its
    // views map — when no inicio step is active its build returns an inert
    // SizedBox.shrink. This lets the `rutaVolverInicio` step spotlight the
    // INICIO bottom-nav button while the user is still on the Ruta tab.
    return Stack(
      children: [
        child,
        GuidedTutorialOverlay(
          screen: GuidedScreen.inicio,
          views: _inicioGuidedViews(),
        ),
      ],
    );
  }

  Map<GuidedStep, GuidedStepView> _inicioGuidedViews() => {
    GuidedStep.gotoMas: GuidedStepView(
      targetKey: _kMasNav,
      title: 'Configurá tu cuenta',
      body: 'Entrá a «Más» (abajo) para configurar tu perfil y tu reparto.',
    ),
    GuidedStep.gotoCarga: GuidedStepView(
      targetKey: _kCarga,
      title: kDemoMode ? 'Carga del día' : 'Cargá tu primer producto',
      body: kDemoMode
          ? 'En la app completa, desde «Registrar carga» preparás los productos que suben al camión.'
          : 'Ahora tocá «Registrar carga» para cargar tu primer producto.',
    ),
    GuidedStep.selectDay: GuidedStepView(
      targetKey: _kDayBtn,
      title: 'Elegí el día',
      body: kDemoMode
          ? 'Este selector cambia el día que estás revisando en el demo.'
          : 'Tocá SELECCIONAR DÍA y elegí el día en que cargaste el producto.',
    ),
    GuidedStep.viewSummary: GuidedStepView(
      targetKey: _kCargaSummary,
      title: 'Tu carga del día',
      body: 'Acá ves el resumen de lo que cargaste hoy. Revisalo y seguí.',
    ),
    GuidedStep.instancias: GuidedStepView(
      targetKey: _kInstanceDropdown,
      title: 'Varios días a la vez',
      body:
          'Con esta flechita podés abrir otra «vista» del mismo reparto '
          'para correr dos días al mismo tiempo — por ejemplo, hacer hoy '
          'el reparto del jueves Y el del viernes (en otro teléfono) '
          'cuando mañana es feriado.',
    ),
    GuidedStep.gotoGastos: GuidedStepView(
      targetKey: _kGastos,
      title: kDemoMode ? 'Gastos' : 'Registrá un gasto',
      body: kDemoMode
          ? 'En la app completa, desde «Registrar gastos» anotás nafta, peajes u otros gastos del día.'
          : 'Ahora entrá a «Registrar gastos» para anotar un gasto del día.',
    ),
    GuidedStep.empezar: GuidedStepView(
      targetKey: _kEmpezar,
      title: kDemoMode ? 'Recorrido' : '¡Arrancá!',
      body: kDemoMode
          ? 'En la app completa, EMPEZAR RECORRIDO activa el seguimiento del reparto.'
          : 'Tocá EMPEZAR RECORRIDO para salir a repartir.',
    ),
    GuidedStep.rutaVolverInicio: GuidedStepView(
      targetKey: _kInicioNav,
      title: '¡Muy bien!',
      body:
          'Cuando termines de repartir, tocá INICIO (abajo) para volver y cerrar el día.',
    ),
    GuidedStep.terminar: GuidedStepView(
      targetKey: _kTerminar,
      title: kDemoMode ? 'Cierre del día' : 'Terminá tu día',
      body: kDemoMode
          ? 'Al terminar un recorrido real, la app completa muestra el cierre con recaudación, gastos, productos y sueldo.'
          : 'Cuando termines de repartir, tocá TERMINAR para cerrar el día.',
    ),
    GuidedStep.p2GotoMas: GuidedStepView(
      targetKey: _kMasNav,
      title: 'Conocé el resto',
      body: 'Por último, entrá a «Más» para ver las otras pantallas de la app.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // While the onboarding tutorial overlay is up, back dismisses it.
        if (_tutorialActive) {
          _exitInicioTutorial();
          return;
        }
        // While the guided setup tutorial is running, back skips it.
        if (TutorialController.instance.active) {
          TutorialController.instance.skip();
          return;
        }
        // If not on Inicio tab, go back to it instead of closing
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        // On Inicio: show confirmation dialog if any recorrido is active
        if (_anyRecorridoActive) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: tokens.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                '¿Salir de la app?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                'Tenés un recorrido en curso. Si salís, no se perderá el progreso.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Minimize app instead of closing
                    SystemNavigator.pop();
                  },
                  child: Text(
                    'Salir',
                    style: TextStyle(color: tokens.primaryBlue),
                  ),
                ),
              ],
            ),
          );
        } else {
          // No active recorrido — minimize app
          SystemNavigator.pop();
        }
      },
      child: _wrapInicioGuided(
        Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: tokens.bg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Phase 3: top dark shell removed entirely. Inicio owns its
                // own light header (with bell). Ruta and MAS handle their
                // own chrome. The hamburger menu (_showMenu) is no longer
                // reachable — every item is in MAS.
                // SyncIndicator stays visible across all tabs so the sodero
                // always knows whether changes are pushing.
                SyncIndicator(),
                // Main content — IndexedStack keeps all tabs alive
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      // Inicio: wrapped in a light-bg Container per the new
                      // Canva design. Ruta and MAS own their own backgrounds.
                      Container(color: tokens.bg, child: _buildInicioContent()),
                      RutaScreen(
                        repartoId: _activeReparto?.id,
                        repartoNombre: _activeReparto?.nombre,
                        selectedDay: _repartoConfirmed
                            ? _configSelectedDay
                            : null,
                        activeSemana: _activeReparto != null
                            ? _semanaForActiveRecorrido(_activeReparto!.id)
                            : null,
                        refreshTrigger: _rutaRefreshTrigger,
                        onStatsChanged: _repartoConfirmed
                            ? _onStatsChanged
                            : null,
                      ),
                      // MAS hub — replaces the old Carga tab. Carga is now
                      // pushed as a route from the Inicio action row or from
                      // inside MAS.
                      MasScreen(
                        userName: _userName,
                        userAvatar: _buildUserAvatar(
                          radius: 22,
                          iconSize: 24,
                          background: tokens.cardBorder,
                          iconColor: tokens.text,
                        ),
                        activeRepartoLabel: _activeRepartoLabelMas,
                        onOpenProfile: _showProfile,
                        onOpenCarga: _pushCargaRoute,
                        onOpenGastos: _pushGastosRoute,
                        onOpenClientes: _pushClientesRoute,
                        onOpenEtiquetas: _pushEtiquetasRoute,
                        onOpenResumenDiario: _pushResumenDiarioRoute,
                        onOpenResumenAnual: _pushResumenAnualRoute,
                        onOpenConfiguracion: _pushConfiguracionRoute,
                        onReplayTutorial: _showTutorialSectionPicker,
                        onSignOut: _handleSignOut,
                      ),
                    ],
                  ),
                ),
                // Bottom nav bar — 3 tabs: Inicio, Ruta, MAS (light theme per
                // Canva design).
                Container(
                  decoration: BoxDecoration(
                    color: tokens.card,
                    border: Border(
                      top: BorderSide(color: tokens.cardBorder, width: 1),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    top: 6,
                    bottom: MediaQuery.of(context).padding.bottom + 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      KeyedSubtree(
                        key: _kInicioNav,
                        child: _buildNavItem(
                          Icons.home_filled,
                          'INICIO',
                          0,
                          onSelect: () {
                            _loadProductRanking();
                            _loadConfigCargaAndCheckChanges();
                            TutorialController.instance.onBackToInicio();
                          },
                        ),
                      ),
                      _buildNavItem(
                        Icons.route_outlined,
                        'RUTA',
                        1,
                        onSelect: () {
                          _rutaRefreshTrigger++;
                        },
                      ),
                      KeyedSubtree(
                        key: _kMasNav,
                        child: _buildNavItem(
                          Icons.more_horiz,
                          'MAS',
                          2,
                          onSelect: () =>
                              TutorialController.instance.onMasOpened(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotifications() {
    setState(() => _unreadNotifCount = 0);
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: notificationsRouteName),
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  // ignore: unused_element
  IconData _notifIcon(String type) {
    switch (type) {
      case 'deuda_weeks':
        return Icons.warning_amber_rounded;
      case 'inactive_weeks':
        return Icons.person_off;
      case 'stock_low':
        return Icons.inventory_2;
      default:
        return Icons.notifications_outlined;
    }
  }

  // ignore: unused_element
  Color _notifIconColor(String type) {
    switch (type) {
      case 'deuda_weeks':
        return tokens.warn;
      case 'inactive_weeks':
        return tokens.textMuted;
      case 'stock_low':
        return tokens.danger;
      default:
        return tokens.primaryBlue;
    }
  }

  // ignore: unused_element
  String _formatTimeAgo(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'ahora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}sem';
    } catch (_) {
      return '';
    }
  }

  void _showProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          activeRepartoNameProvider: () => _activeReparto?.nombre,
          onOpenRepartoSelector: _showRepartoSelector,
        ),
      ),
    ).then((_) {
      if (TutorialController.instance.active) {
        TutorialController.instance.onReturnedFromProfile();
        // The profile phase ends on Inicio (gotoCarga) — bring the user there.
        if (mounted &&
            TutorialController.instance.current?.screen ==
                GuidedScreen.inicio) {
          setState(() => _currentIndex = 0);
        }
      }
    });
  }

  // ignore: unused_element
  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 12),
                if (_userName != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _buildUserAvatar(
                          radius: 20,
                          iconSize: 22,
                          background: Colors.white12,
                        ),
                        SizedBox(width: 12),
                        Text(
                          _userName!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_userName != null)
                  Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: Icon(
                    Icons.local_shipping_outlined,
                    color: Colors.white70,
                  ),
                  title: Text(
                    _activeReparto != null
                        ? 'Reparto: ${_activeReparto!.nombre}'
                        : 'Seleccionar reparto',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(context);
                    _showRepartoSelector();
                  },
                ),
                Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: Icon(Icons.people_outline, color: Colors.white70),
                  title: Text(
                    'Clientes',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(context);
                    if (_activeReparto != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientesScreen(
                            repartoId: _activeReparto!.id,
                            repartoNombre: _activeReparto!.nombre,
                            onClientsChanged: () {
                              setState(() => _rutaRefreshTrigger++);
                              _loadProductRanking();
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
                Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: Icon(Icons.label_outline, color: Colors.white70),
                  title: Text(
                    'Etiquetas',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(context);
                    if (_activeReparto != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EtiquetasScreen(
                            repartoId: _activeReparto!.id,
                            repartoNombre: _activeReparto!.nombre,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) setState(() => _rutaRefreshTrigger++);
                      });
                    }
                  },
                ),
                Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white70,
                  ),
                  title: Text(
                    'Resumen diario',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(context);
                    if (_activeReparto != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResumenHistorialScreen(
                            repartoId: _activeReparto!.id,
                            repartoNombre: _activeReparto!.nombre,
                            workDays: _workDays,
                            onResumenDeleted: _loadUltimaVez,
                          ),
                        ),
                      ).then((_) => _loadUltimaVez());
                    }
                  },
                ),
                Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: Icon(
                    Icons.bar_chart_outlined,
                    color: Colors.white70,
                  ),
                  title: Text(
                    'Resumen anual',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    Navigator.pop(context);
                    if (_activeReparto != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResumenAnualScreen(
                            repartoId: _activeReparto!.id,
                            repartoNombre: _activeReparto!.nombre,
                          ),
                        ),
                      );
                    }
                  },
                ),
                Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: Icon(Icons.settings_outlined, color: Colors.white70),
                  title: Text(
                    'Configuración',
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () async {
                    Navigator.pop(context);
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ConfiguracionScreen(repartoId: _activeReparto?.id),
                      ),
                    );
                    if (changed == true && mounted) {
                      _loadWorkDays();
                      setState(() => _rutaRefreshTrigger++);
                    }
                  },
                ),
                Divider(color: tokens.cardBorder, height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: tokens.textSub),
                  title: Text(
                    'Cerrar sesión',
                    style: TextStyle(color: tokens.text),
                  ),
                  onTap: () async {
                    // Capture navigator and overlay context before closing menu
                    final nav = Navigator.of(context, rootNavigator: true);
                    final overlayContext = nav.overlay?.context;
                    Navigator.pop(context); // close the menu
                    if (overlayContext == null) return;
                    if (kDemoMode) {
                      showDemoUpgradeSnack(overlayContext);
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(overlayContext);
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: overlayContext,
                      useRootNavigator: true,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: tokens.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Cerrar sesión',
                          style: TextStyle(color: tokens.text),
                        ),
                        content: Text(
                          '¿Estás seguro de que querés cerrar sesión?',
                          style: TextStyle(color: tokens.textSub),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: tokens.textSub),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Cerrar sesión',
                              style: TextStyle(color: tokens.danger),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !overlayContext.mounted) return;
                    _authSub
                        ?.cancel(); // prevent auth listener from double-navigating
                    // Show loading spinner while syncing + signing out
                    showDialog(
                      context: overlayContext,
                      barrierDismissible: false,
                      useRootNavigator: true,
                      builder: (_) => Center(
                        child: CircularProgressIndicator(
                          color: tokens.primaryBlue,
                        ),
                      ),
                    );
                    // Phase 10g: handle the blocked-unsynced result.
                    var result = await AuthService.signOut();
                    if (result is SignOutBlocked) {
                      // Dismiss the spinner so we can show a dialog.
                      if (nav.canPop()) nav.pop();
                      final pending = result.pendingItemCount;
                      if (!overlayContext.mounted) return;
                      final forceConfirm = await showDialog<bool>(
                        context: overlayContext,
                        builder: (dCtx) => AlertDialog(
                          title: Text('Hay cambios sin sincronizar'),
                          content: Text(
                            'Hay $pending cambio${pending == 1 ? '' : 's'} '
                            'sin sincronizar. Si cerrás sesión ahora, '
                            'se perderán. ¿Continuar igualmente?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              style: TextButton.styleFrom(
                                foregroundColor: tokens.danger,
                              ),
                              child: Text('Cerrar sesión igual'),
                            ),
                          ],
                        ),
                      );
                      if (forceConfirm != true || !overlayContext.mounted) {
                        return;
                      }
                      // Re-show spinner for the forced wipe.
                      showDialog(
                        context: overlayContext,
                        barrierDismissible: false,
                        useRootNavigator: true,
                        builder: (_) => Center(
                          child: CircularProgressIndicator(
                            color: tokens.primaryBlue,
                          ),
                        ),
                      );
                      result = await AuthService.signOut(forceWipe: true);
                    }
                    if (!result.success) {
                      if (nav.canPop()) nav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'No se pudo cerrar sesión: no se limpiaron las credenciales locales.',
                          ),
                          backgroundColor: tokens.danger,
                        ),
                      );
                      return;
                    }
                    _exitInicioTutorial();
                    TutorialController.instance.skip();
                    if (nav.canPop()) nav.pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // MAS helpers — Phase 1 route pushers and sign-out flow.
  // Each handler covers the no-active-reparto path with a snackbar
  // so we never silently fail.

  String get _activeRepartoLabelMas {
    if (_activeReparto != null) return _activeReparto!.nombre;
    return 'Sin reparto seleccionado';
  }

  void _flashSinReparto() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Seleccioná un reparto primero'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _pushCargaRoute() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CargaScreen(
              repartoId: _activeReparto?.id,
              repartoNombre: _activeReparto?.nombre,
              workDays: _workDays,
              // Pass null (not -1) when no day is picked so Carga's
              // `_effectiveDay` falls back to its own initialized _selectedDay
              // instead of indexing _allDayNames[-1].
              selectedDay: _configSelectedDay >= 0 ? _configSelectedDay : null,
              // Carga owns its day selector. Inicio's day selector is a separate
              // explicit choice, so tapping a day in Carga must not preselect it
              // back on Inicio.
              onCargaChanged: _onCargaChanged,
            ),
          ),
        )
        .then((_) {
          if (TutorialController.instance.active) {
            TutorialController.instance.onReturnedFromCarga();
          }
        });
  }

  void _pushGastosRoute() {
    // Guard: gastos need a confirmed reparto + selected day, otherwise
    // _saveTodayGastos silently bails and the sodero loses their input.
    if (_activeReparto == null) {
      _flashSinReparto();
      return;
    }
    if (!_repartoConfirmed || _configSelectedDay < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seleccioná el día primero para registrar gastos'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => GastosScreen(
              todayGastos: List<Map<String, dynamic>>.from(_todayGastos),
              productGastos: _productGastos,
              onTodayGastosChanged: (newList) async {
                if (!mounted) return;
                setState(() {
                  _todayGastos
                    ..clear()
                    ..addAll(newList);
                });
                await _saveTodayGastos();
              },
            ),
          ),
        )
        .then((_) {
          if (TutorialController.instance.active) {
            TutorialController.instance.onReturnedFromGastos();
          }
        });
  }

  void _pushClientesRoute() {
    if (_activeReparto == null) {
      _flashSinReparto();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientesScreen(
          repartoId: _activeReparto!.id,
          repartoNombre: _activeReparto!.nombre,
          onClientsChanged: () {
            setState(() => _rutaRefreshTrigger++);
            _loadProductRanking();
          },
        ),
      ),
    ).then((_) {
      if (TutorialController.instance.active) {
        TutorialController.instance.onP2Return(GuidedScreen.clientes);
      }
    });
    TutorialController.instance.onP2Open(GuidedScreen.clientes);
  }

  void _pushEtiquetasRoute() {
    if (_activeReparto == null) {
      _flashSinReparto();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EtiquetasScreen(
          repartoId: _activeReparto!.id,
          repartoNombre: _activeReparto!.nombre,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _rutaRefreshTrigger++);
      if (TutorialController.instance.active) {
        TutorialController.instance.onP2Return(GuidedScreen.etiquetas);
      }
    });
    TutorialController.instance.onP2Open(GuidedScreen.etiquetas);
  }

  void _pushResumenDiarioRoute() {
    if (_activeReparto == null) {
      _flashSinReparto();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResumenHistorialScreen(
          repartoId: _activeReparto!.id,
          repartoNombre: _activeReparto!.nombre,
          workDays: _workDays,
          onResumenDeleted: _loadUltimaVez,
        ),
      ),
    ).then((_) {
      _loadUltimaVez();
      if (TutorialController.instance.active) {
        TutorialController.instance.onP2Return(GuidedScreen.resumenDiario);
      }
    });
    TutorialController.instance.onP2Open(GuidedScreen.resumenDiario);
  }

  void _pushResumenAnualRoute() {
    if (_activeReparto == null) {
      _flashSinReparto();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResumenAnualScreen(
          repartoId: _activeReparto!.id,
          repartoNombre: _activeReparto!.nombre,
        ),
      ),
    ).then((_) {
      if (TutorialController.instance.active) {
        TutorialController.instance.onP2Return(GuidedScreen.resumenAnual);
      }
    });
    TutorialController.instance.onP2Open(GuidedScreen.resumenAnual);
  }

  void _pushConfiguracionRoute() async {
    TutorialController.instance.onP2Open(GuidedScreen.config);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfiguracionScreen(repartoId: _activeReparto?.id),
      ),
    );
    if (changed == true && mounted) {
      _loadWorkDays();
      setState(() => _rutaRefreshTrigger++);
    }
    if (TutorialController.instance.active) {
      TutorialController.instance.onP2Return(GuidedScreen.config);
    }
  }

  void _handleSignOut() async {
    final nav = Navigator.of(context, rootNavigator: true);
    final overlayContext = nav.overlay?.context;
    if (overlayContext == null) return;
    if (kDemoMode) {
      showDemoUpgradeSnack(overlayContext);
      return;
    }
    final messenger = ScaffoldMessenger.of(overlayContext);
    final confirmed = await showDialog<bool>(
      context: overlayContext,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cerrar sesión', style: TextStyle(color: tokens.text)),
        content: Text(
          '¿Estás seguro de que querés cerrar sesión?',
          style: TextStyle(color: tokens.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cerrar sesión',
              style: TextStyle(color: tokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !overlayContext.mounted) return;
    _authSub?.cancel();
    showDialog(
      context: overlayContext,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) =>
          Center(child: CircularProgressIndicator(color: tokens.primaryBlue)),
    );
    var result = await AuthService.signOut();
    if (result is SignOutBlocked) {
      if (nav.canPop()) nav.pop();
      final pending = result.pendingItemCount;
      if (!overlayContext.mounted) return;
      final forceConfirm = await showDialog<bool>(
        context: overlayContext,
        builder: (dCtx) => AlertDialog(
          title: Text('Hay cambios sin sincronizar'),
          content: Text(
            'Hay $pending cambio${pending == 1 ? '' : 's'} '
            'sin sincronizar. Si cerrás sesión ahora, '
            'se perderán. ¿Continuar igualmente?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              style: TextButton.styleFrom(foregroundColor: tokens.danger),
              child: Text('Cerrar sesión igual'),
            ),
          ],
        ),
      );
      if (forceConfirm != true || !overlayContext.mounted) return;
      showDialog(
        context: overlayContext,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) =>
            Center(child: CircularProgressIndicator(color: tokens.primaryBlue)),
      );
      result = await AuthService.signOut(forceWipe: true);
    }
    if (!result.success) {
      if (nav.canPop()) nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cerrar sesión: no se limpiaron las credenciales locales.',
          ),
          backgroundColor: tokens.danger,
        ),
      );
      return;
    }
    _exitInicioTutorial();
    TutorialController.instance.skip();
    if (nav.canPop()) nav.pop();
  }

  int _configCargaTotalUnits() {
    return _configCarga.values.fold<int>(0, (sum, qty) => sum + qty);
  }

  // ─── Onboarding tutorial (Inicio coachmark) ───

  List<CoachmarkStep> _inicioSteps({bool chain = true}) => [
    CoachmarkStep(
      targetKey: _kHeaderText,
      title: 'Tu día de hoy',
      body: 'Acá ves la fecha y el reparto con el que estás trabajando hoy.',
    ),
    CoachmarkStep(
      targetKey: _kHojaDeRuta,
      title: 'Tu recorrido',
      body:
          'Elegí el día y tocá EMPEZAR RECORRIDO para salir a repartir. '
          'Desde acá manejás la ruta del día.',
    ),
    CoachmarkStep(
      targetKey: _kStats,
      title: 'Cómo venís hoy',
      body:
          'Un vistazo rápido: clientes visitados, botellones vendidos, lo que '
          'recaudaste y lo que gastaste en el día.',
    ),
    CoachmarkStep(
      targetKey: _kCarga,
      title: 'Registrar carga',
      body:
          'Anotá los botellones que subís al camión (20L, 12L…). Así la app '
          'sabe con cuánta mercadería arrancás.',
    ),
    CoachmarkStep(
      targetKey: _kGastos,
      title: 'Registrar gastos',
      body:
          'Cargá los gastos del día —nafta, viáticos, reparaciones— para que '
          'tu resumen cierre bien.',
    ),
    CoachmarkStep(
      targetKey: _kBell,
      title: 'Novedades',
      body:
          'La campanita te avisa de mensajes y novedades. Si tiene un punto '
          'rojo, tenés algo sin leer.',
    ),
    CoachmarkStep(
      title: '¡Listo!',
      body: chain
          ? 'Ahora vamos a configurar tu cuenta y crear tu reparto. Seguime.'
          : 'Eso es lo principal de la pantalla de Inicio.',
    ),
  ];

  /// Run the Inicio coachmark. When [chainToGuided] is true (auto-launch /
  /// "Tutorial completo") it continues into the full guided flow on completion;
  /// when false (the "Inicio" section) it stands alone.
  void _startInicioCoachmark({required bool chainToGuided}) {
    if (_tutorialActive || _coachmark.isActive) return;
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tutorialActive || _coachmark.isActive) return;
      setState(() => _tutorialActive = true);
      _coachmark.start(
        context: context,
        steps: _inicioSteps(chain: chainToGuided),
        scrollController: _inicioScrollCtrl,
        onFinish: chainToGuided
            ? _finishInicioCoachmark
            : _finishInicioCoachmarkStandalone,
        onSkip: _exitInicioTutorial,
      );
    });
  }

  void _finishInicioCoachmark() {
    // Natural completion → continue into the guided setup flow. Skip/X does
    // NOT start it, so a user who dismisses the intro isn't dragged through.
    if (mounted) setState(() => _tutorialActive = false);
    TutorialController.instance.start(repartoId: _activeReparto?.id);
  }

  void _finishInicioCoachmarkStandalone() {
    // Inicio SECTION (from the picker): just close the coachmark, don't chain.
    if (mounted) setState(() => _tutorialActive = false);
    _markTutorialSeen();
  }

  // ─── Tutorial section picker (replay from Más) ───

  Future<void> _showTutorialSectionPicker() async {
    if (_tutorialActive ||
        _coachmark.isActive ||
        TutorialController.instance.active) {
      return;
    }
    final reparto = _activeReparto;
    var hasClientToday = false;
    if (reparto != null) {
      final todayDow = argentinaTime().weekday - 1; // 0=Mon … 6=Sun
      final clients = await _db.getClientesForRepartoDay(reparto.id, todayDow);
      hasClientToday = clients.isNotEmpty;
    }
    if (!mounted) return;
    final section = await showDialog<_TutorialSection>(
      context: context,
      builder: (ctx) =>
          _buildTutorialSectionDialog(ctx, reparto != null, hasClientToday),
    );
    if (section != null && mounted) _launchTutorialSection(section);
  }

  Widget _buildTutorialSectionDialog(
    BuildContext ctx,
    bool hasReparto,
    bool hasClientToday,
  ) {
    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required _TutorialSection section,
      bool enabled = true,
    }) {
      return Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => Navigator.pop(ctx, section) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, color: tokens.primaryBlue, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: tokens.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 12.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (enabled)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: tokens.textMuted,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final cargaSubtitle = hasClientToday
        ? (kDemoMode
              ? 'Recorré carga, ruta y cierre como explicación guiada.'
              : 'Cargá productos, salí a repartir y cerrá el día (práctica real).')
        : (hasReparto
              ? 'Agregá un cliente para hoy para practicar esta sección.'
              : 'Creá un reparto primero (sección Perfil y reparto).');

    return AlertDialog(
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: Text(
        '¿Qué querés repasar?',
        style: TextStyle(
          color: tokens.text,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(
              icon: Icons.play_circle_outline,
              title: 'Tutorial completo',
              subtitle: 'Todo, de principio a fin.',
              section: _TutorialSection.completo,
            ),
            row(
              icon: Icons.home_outlined,
              title: 'Inicio',
              subtitle: 'La pantalla principal y sus botones.',
              section: _TutorialSection.inicio,
            ),
            row(
              icon: Icons.person_outline,
              title: 'Perfil y reparto',
              subtitle: 'Configurá tu perfil y creá tu reparto.',
              section: _TutorialSection.perfil,
            ),
            row(
              icon: Icons.local_shipping_outlined,
              title: 'Carga y ruta',
              subtitle: cargaSubtitle,
              section: _TutorialSection.cargaRuta,
              enabled: kDemoMode || hasClientToday,
            ),
            row(
              icon: Icons.more_horiz,
              title: 'Las demás pantallas',
              subtitle: 'Clientes, etiquetas, resúmenes y configuración.',
              section: _TutorialSection.mas,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cerrar', style: TextStyle(color: tokens.textMuted)),
        ),
      ],
    );
  }

  void _launchTutorialSection(_TutorialSection section) {
    final repId = _activeReparto?.id;
    switch (section) {
      case _TutorialSection.completo:
        _startInicioCoachmark(chainToGuided: true);
        return;
      case _TutorialSection.inicio:
        _startInicioCoachmark(chainToGuided: false);
        return;
      case _TutorialSection.perfil:
        _startGuidedSection(
          tabIndex: 2, // Más
          from: GuidedStep.openProfile,
          stopAfter: GuidedStep.perfilBack,
          repId: repId,
        );
        return;
      case _TutorialSection.cargaRuta:
        _startGuidedSection(
          tabIndex: 0, // Inicio
          from: kDemoMode ? GuidedStep.selectDay : GuidedStep.gotoCarga,
          stopAfter: kDemoMode
              ? GuidedStep.rutaCliente
              : GuidedStep.cierreFinalizar,
          repId: repId,
        );
        return;
      case _TutorialSection.mas:
        _startGuidedSection(
          tabIndex: kDemoMode ? 0 : 2, // Inicio in demo, Más in full flow
          from: kDemoMode ? GuidedStep.p2GotoMas : GuidedStep.p2GotoClientes,
          stopAfter: GuidedStep.tutorialDone,
          repId: repId,
        );
        return;
    }
  }

  void _startGuidedSection({
    required int tabIndex,
    required GuidedStep from,
    required GuidedStep stopAfter,
    int? repId,
  }) {
    if (_currentIndex != tabIndex) {
      setState(() => _currentIndex = tabIndex);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TutorialController.instance.start(
        from: from,
        stopAfter: stopAfter,
        repartoId: repId,
      );
    });
  }

  void _exitInicioTutorial() {
    _coachmark.dismiss();
    _markTutorialSeen();
    if (mounted) setState(() => _tutorialActive = false);
  }

  void _handleGuidedTutorialExit(TutorialExitReason _) {
    _markTutorialSeen();
  }

  void _handleGuidedScreenRequest(GuidedScreen screen) {
    unawaited(_navigateToGuidedScreen(screen));
  }

  Future<void> _navigateToGuidedScreen(GuidedScreen screen) async {
    if (!mounted) return;
    final nav = Navigator.of(context);

    Future<void> showTab(int index) async {
      if (nav.canPop()) {
        await nav.maybePop();
      }
      if (!mounted) return;
      setState(() {
        _currentIndex = index;
        if (index == 1) _rutaRefreshTrigger++;
      });
    }

    Future<void> showMasThen(VoidCallback open) async {
      await showTab(2);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) open();
      });
    }

    switch (screen) {
      case GuidedScreen.inicio:
        await showTab(0);
        break;
      case GuidedScreen.mas:
        await showTab(2);
        break;
      case GuidedScreen.ruta:
        await showTab(1);
        break;
      case GuidedScreen.profile:
        await showMasThen(_showProfile);
        break;
      case GuidedScreen.carga:
        await showTab(0);
        if (mounted) _pushCargaRoute();
        break;
      case GuidedScreen.gastos:
        await showTab(0);
        if (mounted) _pushGastosRoute();
        break;
      case GuidedScreen.cierre:
        await showTab(0);
        if (mounted) _showCierreSummary();
        break;
      case GuidedScreen.clientes:
        await showMasThen(_pushClientesRoute);
        break;
      case GuidedScreen.etiquetas:
        await showMasThen(_pushEtiquetasRoute);
        break;
      case GuidedScreen.resumenDiario:
        await showMasThen(_pushResumenDiarioRoute);
        break;
      case GuidedScreen.resumenAnual:
        await showMasThen(_pushResumenAnualRoute);
        break;
      case GuidedScreen.config:
        await showMasThen(_pushConfiguracionRoute);
        break;
    }
  }

  void _markTutorialSeen() {
    final uid = AuthService.currentUserId ?? '';
    unawaited(OnboardingService.markInicioTutorialSeen(uid));
  }

  void _maybeAutoStartTutorial() {
    if (kDemoMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = AuthService.currentUserId ?? '';
      if (uid.isEmpty) return;
      final seen = await OnboardingService.hasSeenInicioTutorial(uid);
      if (!mounted || seen || _tutorialActive || _coachmark.isActive) return;
      _startInicioCoachmark(chainToGuided: true);
    });
  }

  Widget _buildInicioContent() {
    final totalCarga = _configCargaTotalUnits();
    final gastosTotal = _allGastos.fold<double>(
      0,
      (sum, gasto) => sum + ((gasto['monto'] as num?)?.toDouble() ?? 0),
    );
    final clientesValue = _showStats
        ? '$_liveClientesVisited/$_liveClientesTotal'
        : '—/—';
    final cargaValue = _showStats
        ? '$_liveProductosBought u/$totalCarga u'
        : '—/—';
    final recaudadoValue = _showStats ? _formatMoney(_liveRecaudado) : '—';
    final gastosValue = _showStats ? _formatMoney(gastosTotal) : '—';
    final recaudadoAccent = _showStats && _liveRecaudado > 0
        ? tokens.success
        : null;
    final gastosAccent = _showStats && gastosTotal > 0 ? tokens.danger : null;

    return SingleChildScrollView(
      controller: _inicioScrollCtrl,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInicioHeader(),
          SizedBox(height: 18),
          KeyedSubtree(key: _kHojaDeRuta, child: _buildHojaDeRutaBox()),
          SizedBox(height: 16),
          KeyedSubtree(
            key: _kStats,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildLightStatTile(
                          label: 'CLIENTES',
                          value: clientesValue,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildLightStatTile(
                          label: 'CARGA',
                          value: cargaValue,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildLightStatTile(
                          label: 'RECAUDADO',
                          value: recaudadoValue,
                          accent: recaudadoAccent,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildLightStatTile(
                          label: 'GASTOS',
                          value: gastosValue,
                          accent: gastosAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          _buildInicioActionRows(),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInicioHeader() {
    final vistaName = _currentNonDefaultInstanceName;
    final repartoLabel = _activeReparto?.nombre ?? 'Seleccioná un reparto';
    final greeting = vistaName == null
        ? repartoLabel
        : '$repartoLabel · $vistaName';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            key: _kHeaderText,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _formattedDate(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  // v85 «Instancias»: the vistas dropdown — switch/create
                  // parallel day-views of the active reparto.
                  if (_activeReparto != null)
                    InkWell(
                      key: _kInstanceDropdown,
                      onTap: _showInstancePicker,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: tokens.textSub,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                greeting,
                style: TextStyle(
                  color: tokens.textSub,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        // Notification bell (white card with red dot if unread).
        Material(
          key: _kBell,
          color: tokens.card,
          borderRadius: BorderRadius.circular(12),
          elevation: 0,
          child: InkWell(
            onTap: _showNotifications,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.cardBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: tokens.text,
                    size: 20,
                  ),
                  if (_unreadNotifCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: tokens.danger,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: tokens.card, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            // Centrado óptico: sin esto el leading de la
                            // fuente empuja el número hacia abajo dentro
                            // de la burbuja.
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                        ),
                      ),
                    ),
                  if (_unreadAdminMessageCount > 0)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: tokens.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.card, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLightStatTile({
    required String label,
    required String value,
    Color? accent,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: accent ?? tokens.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInicioActionRows() {
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          KeyedSubtree(
            key: _kCarga,
            child: _buildActionRow(
              icon: Icons.local_shipping_outlined,
              iconBg: tokens.actionRowGastosTint,
              iconColor: tokens.danger,
              title: 'Registrar carga',
              subtitle: 'Botellones de 20L, 12L…',
              onTap: _pushCargaRoute,
            ),
          ),
          Divider(
            color: tokens.cardBorder,
            height: 1,
            indent: 64,
            endIndent: 0,
          ),
          KeyedSubtree(
            key: _kGastos,
            child: _buildActionRow(
              icon: Icons.payments_outlined,
              iconBg: tokens.actionRowCargaTint,
              iconColor: tokens.primaryBlue,
              title: 'Registrar gastos',
              subtitle: 'Nafta, viáticos, reparación…',
              onTap: _pushGastosRoute,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: tokens.textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: tokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHojaDeRutaBox() {
    final hasReparto = _activeReparto != null;
    final hasDay = _configSelectedDay >= 0;
    final confirmedDayName = hasDay && _configSelectedDay < _allDayNames.length
        ? _allDayNames[_configSelectedDay]
        : '';
    final resumeAvailable =
        _activeReparto != null &&
        _configSelectedDay >= 0 &&
        (_endedRecorridoDays[_activeReparto!.id]?.contains(
              _configSelectedDay,
            ) ??
            false);
    final empezarEnabled =
        hasReparto && ((hasDay && _repartoConfirmed) || resumeAvailable);
    final totalCargaProductos = _configCargaTotalUnits();
    // CARGA DEL DÍA total = the product-gasto subtotal (cost of the loaded
    // carga). Reuses _productGastos so it always matches the gastos numbers
    // shown elsewhere; differs from the Inicio gastos KPI only by any manual
    // gastos (those are not part of the carga), which is intended.
    final totalCargaValue = _productGastos.fold<double>(
      0,
      (sum, g) => sum + ((g['monto'] as num?)?.toDouble() ?? 0),
    );
    final showCargaSummary = _repartoConfirmed && totalCargaProductos > 0;

    if (!_isRecorridoForCurrentReparto) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RUTA DE HOY',
              style: TextStyle(
                color: tokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: 16),
            // SELECCIONAR DÍA — blue when no day is picked (call-to-action),
            // grey when a day is already chosen (done — still tappable to
            // change). This pairs with the inverse-grey EMPEZAR RECORRIDO
            // below so the active button is always the colored one.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                key: _kDayBtn,
                onPressed: hasReparto ? _openDayPicker : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasDay && _repartoConfirmed
                      ? tokens.disabled
                      : tokens.primaryBlue,
                  // When a day is confirmed, paint the label in
                  // primaryBlue so the chosen day stands out against the
                  // grey backdrop and reads as a confirmation chip.
                  foregroundColor: hasDay && _repartoConfirmed
                      ? tokens.primaryBlue
                      : Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: tokens.disabled,
                  disabledForegroundColor: tokens.disabledFg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  hasDay
                      ? 'DÍA: ${confirmedDayName.toUpperCase()}'
                      : 'SELECCIONAR DÍA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            // EMPEZAR RECORRIDO — gray when day not selected, blue when ready.
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                key: _kEmpezar,
                onPressed: empezarEnabled ? _startRecorrido : null,
                icon: Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: empezarEnabled ? Colors.white : tokens.disabledFg,
                ),
                label: Text(
                  resumeAvailable ? 'REANUDAR RECORRIDO' : 'EMPEZAR RECORRIDO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: tokens.disabled,
                  disabledForegroundColor: tokens.disabledFg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (showCargaSummary) ...[
              SizedBox(height: 16),
              Container(height: 1, color: tokens.cardBorder),
              SizedBox(height: 14),
              // Section header + loaded product rows.
              KeyedSubtree(
                key: _kCargaSummary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 14,
                          color: tokens.textMuted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CARGA DEL DÍA',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Text(
                          _cargaGastosEnabled
                              ? _formatMoney(totalCargaValue)
                              : 'Solo cantidades',
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    // Itemized list — name left, qty right. Tabular figures keep
                    // the quantity column aligned across rows.
                    for (var i = 0; i < _configProducts.length; i++)
                      if ((_configCarga[_configProducts[i].id] ?? 0) > 0)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _configProducts[i].nombre,
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                formatPackQty(
                                  _configCarga[_configProducts[i].id] ?? 0,
                                  _configPackSizes[_configProducts[i].id],
                                ),
                                style: TextStyle(
                                  color: tokens.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    final visited = _liveClientesVisited;
    final total = _liveClientesTotal;
    final remainingClients = total - visited;
    String estimatedRemaining;
    if (visited > 0 && remainingClients > 0) {
      final perClient = _currentElapsed.inSeconds / visited;
      final remSec = (perClient * remainingClients).round();
      final h = remSec ~/ 3600;
      final m = ((remSec % 3600) / 60).floor();
      estimatedRemaining = h > 0 ? '${h}h ${m}min' : '${m}min';
    } else {
      estimatedRemaining = '—';
    }
    final progressPct = total > 0
        ? ((visited * 100) / total).clamp(0, 100).round()
        : 0;

    Widget miniPanel(String label, String value) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tokens.heroBlue, tokens.heroBlueDeeper],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tokens.heroBlueDeeper.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _recorridoPulseCtrl,
                  curve: Curves.easeInOut,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'EN RECORRIDO...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              _formatDuration(_currentElapsed),
              style: TextStyle(
                color: Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w800,
                height: 1.05,
                // tabularFigures keeps the digit columns aligned without
                // forcing a monospace font for the whole numeral.
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              miniPanel('RESTANTE EST.', estimatedRemaining),
              SizedBox(width: 10),
              miniPanel('PROGRESO', '$visited / $total · $progressPct%'),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              // IR A RUTA — primary action: solid white card with brand-blue
              // ink so it pops clearly against the gradient background.
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _currentIndex = 1),
                    icon: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: tokens.heroBlue,
                    ),
                    label: Text(
                      'IR A RUTA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: tokens.heroBlue,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: tokens.heroBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              // TERMINAR — matches IR A RUTA visually (solid white card + blue
              // ink). Confirmation dialog handles accidental taps.
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: _kTerminar,
                    onPressed: _confirmEndRecorrido,
                    icon: Icon(
                      Icons.stop_rounded,
                      size: 16,
                      color: tokens.heroBlue,
                    ),
                    label: Text(
                      'TERMINAR',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: tokens.heroBlue,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: tokens.heroBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom sheet day picker for the hero box. Tapping a day selects it
  /// (auto-confirms the reparto). Tapping the already-selected day
  /// clears the selection. Either way the sheet closes.
  void _openDayPicker() {
    if (_activeReparto == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 12, 0, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Elegí el día',
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _configSelectedDay >= 0
                        ? 'Tocá el día seleccionado para quitarlo'
                        : '',
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                ),
                SizedBox(height: 8),
                ..._workDays.map((i) {
                  final isSelected = _configSelectedDay == i;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _configSelectedDay = -1;
                          _repartoConfirmed = false;
                          _todayResumenId = null;
                          _todayGastos = [];
                        } else {
                          _configSelectedDay = i;
                          _repartoConfirmed = true;
                          _configExpanded = false;
                          _todayResumenId = null;
                          _todayGastos = [];
                        }
                      });
                      if (!isSelected) {
                        _loadConfigCarga();
                        _ensureTodayResumen();
                        _loadUltimaVez();
                        TutorialController.instance.onDaySelected(i);
                      }
                      // v85: a non-default vista persists its day on the
                      // synced registry entry (default keeps today's
                      // pick-daily, device-local behavior).
                      unawaited(
                        _persistInstanceDaySelection(isSelected ? -1 : i),
                      );
                      Navigator.of(sheetCtx).pop();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _allDayNames[i],
                              style: TextStyle(
                                color: isSelected
                                    ? tokens.primaryBlue
                                    : tokens.text,
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              color: tokens.primaryBlue,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Compact monthly top-3 products card — replaces the old expandable
  /// "Ranking de ventas" section. Fits aesthetically at the bottom of the
  /// Inicio without dominating the screen.
  // ignore: unused_element
  Widget _buildTopProductosCard() {
    final m = DateFormat('MMMM', 'es_AR').format(argentinaTime());
    final monthName = m[0].toUpperCase() + m.substring(1);
    final nonZero = _rankedProducts.where((p) => p.quantity > 0).toList();
    final top = nonZero.take(3).toList();
    final maxQty = top.fold<int>(
      0,
      (acc, p) => p.quantity > acc ? p.quantity : acc,
    );
    final totalUnits = nonZero.fold<int>(0, (acc, p) => acc + p.quantity);

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Más vendidos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '· $monthName',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 14,
                ),
              ),
              Spacer(),
              if (totalUnits > 0)
                Text(
                  '$totalUnits u',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          SizedBox(height: 14),
          if (top.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Sin entregas registradas este mes',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            )
          else
            ...List.generate(top.length, (i) {
              final p = top[i];
              final widthFactor = maxQty > 0 ? p.quantity / maxQty : 0.0;
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? tokens.primaryBlue.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == 0
                                  ? tokens.primaryBlue
                                  : Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${p.quantity}u',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: widthFactor.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          i == 0
                              ? tokens.primaryBlue
                              : tokens.primaryBlue.withValues(alpha: 0.55),
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Last-7-days unit total + mini sparkline of daily units. Mirrors the
  /// web Finanzas page's `_SparkLine` KPI but compact for the mobile grid.
  // ignore: unused_element
  Widget _buildSparkLineCard() {
    final total = _last7DaysUnits.fold<int>(0, (a, b) => a + b);
    final hasData = total > 0;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Últimos 7 días',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          SizedBox(height: 6),
          Text(
            hasData ? '${total}u' : '—',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 30,
            width: double.infinity,
            child: CustomPaint(
              painter: _MiniSparkLinePainter(
                values: _last7DaysUnits,
                color: tokens.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDesignStatCard(
    String label,
    String value,
    String sub, {
    Color? accent,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accent ?? Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (sub.isNotEmpty) ...[
            SizedBox(height: 2),
            Text(sub, style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildConfigRepartoPanel() {
    final hasReparto = _activeReparto != null;
    final confirmedDayName =
        _configSelectedDay >= 0 && _configSelectedDay < _allDayNames.length
        ? _allDayNames[_configSelectedDay]
        : '';

    // Compact chip when a recorrido is running — the colored hero box owns
    // the visual weight; this just reminds the sodero which reparto+day is
    // active without competing with the gradient card below.
    if (_isRecorridoForCurrentReparto && hasReparto) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: tokens.success, size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_activeReparto!.nombre} · $confirmedDayName',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Header text (button-style, centered)
    final String headerText = _repartoConfirmed && hasReparto
        ? '${_activeReparto!.nombre}: $confirmedDayName'
        : 'Configurar reparto de hoy';

    // Button styling — filled CTA when not yet configured, ghost when
    // confirmed or expanded. Mirrors the Empezar recorrido button's look
    // for visual consistency.
    final bool isUnconfirmed = hasReparto && !_repartoConfirmed;
    final bool showAsCta = isUnconfirmed && !_configExpanded;
    final Color buttonBg = showAsCta ? tokens.primaryBlue : tokens.card;
    final Color buttonBorder = showAsCta
        ? tokens.primaryBlue
        : (_repartoConfirmed && hasReparto && !_configExpanded
              ? tokens.primaryBlue.withValues(alpha: 0.45)
              : tokens.cardBorder);

    return Column(
      children: [
        // Header button — filled or ghost depending on state
        Material(
          color: buttonBg,
          borderRadius: _configExpanded
              ? BorderRadius.vertical(top: Radius.circular(16))
              : BorderRadius.circular(16),
          child: InkWell(
            onTap: hasReparto
                ? () {
                    setState(() => _configExpanded = !_configExpanded);
                    if (_configExpanded) _loadConfigCarga();
                  }
                : null,
            borderRadius: _configExpanded
                ? BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: _configExpanded
                    ? BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
                border: Border.all(color: buttonBorder, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_repartoConfirmed && hasReparto) ...[
                    Icon(Icons.check_circle, color: tokens.success, size: 18),
                    SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      hasReparto ? headerText : 'Seleccioná un reparto primero',
                      style: TextStyle(
                        color: hasReparto
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expanded content
        if (_configExpanded && hasReparto)
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(
                left: BorderSide(color: tokens.cardBorder),
                right: BorderSide(color: tokens.cardBorder),
                bottom: BorderSide(color: tokens.cardBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12),
                // Day selector
                Text(
                  'Día del recorrido',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _workDays.map((i) {
                      final isSelected = _configSelectedDay == i;
                      return Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _configSelectedDay = i;
                              _repartoConfirmed = false;
                              _todayResumenId = null;
                              _todayGastos = [];
                            });
                            _loadConfigCarga();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tokens.primaryBlue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? tokens.primaryBlue
                                    : tokens.cardBorder,
                              ),
                            ),
                            child: Text(
                              _allDayNames[i],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 16),
                // Carga summary
                Text(
                  'Resumen de carga',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                _buildCargaSummary(),
                SizedBox(height: 16),
                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _configSelectedDay >= 0
                        ? () {
                            setState(() {
                              _repartoConfirmed = true;
                              _configExpanded = false;
                            });
                            _ensureTodayResumen();
                            _loadUltimaVez();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white10,
                      disabledForegroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirmar reparto',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCargaSummary() {
    // Filter to only products with quantity > 0
    final loaded = _configProducts
        .where((p) => (_configCarga[p.id] ?? 0) > 0)
        .toList();

    if (_configProducts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: tokens.primaryBlue,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (loaded.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Sin productos cargados para ${_allDayNames[_configSelectedDay].toLowerCase()}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 13,
          ),
        ),
      );
    }

    return Column(
      children: loaded.map((product) {
        final qty = formatPackQty(
          _configCarga[product.id] ?? 0,
          _configPackSizes[product.id],
        );
        return Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  product.nombre,
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              SizedBox(width: 8),
              Text(
                qty,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ignore: unused_element
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white54, size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '\$${amount.toStringAsFixed(0)}';
  }

  void _onGastoFocusChanged() {
    final focused = _gastoDescFocus.hasFocus || _gastoMontoFocus.hasFocus;
    if (focused != _gastoFieldFocused) {
      setState(() => _gastoFieldFocused = focused);
      if (focused) {
        _scrollToFocusedGastoField();
      }
    }
  }

  void _scrollToFocusedGastoField() {
    final focusNode = _gastoDescFocus.hasFocus
        ? _gastoDescFocus
        : _gastoMontoFocus;
    // Wait for the extra padding SizedBox to be laid out, then ensure visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = focusNode.context;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  // ignore: unused_element
  Widget _buildHomeGastosCard() {
    final allGastos = _allGastos;
    double totalGastos = 0;
    for (final g in allGastos) {
      totalGastos += ((g['monto'] as num?)?.toDouble() ?? 0);
    }

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: Colors.white.withValues(alpha: 0.5),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GASTOS DEL DÍA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 8),
              if (totalGastos > 0)
                Text(
                  '\$${totalGastos.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: tokens.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          SizedBox(height: 10),
          // Manual gasto input row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _homeGastoDescCtrl,
                    focusNode: _gastoDescFocus,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Descripción',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 13,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: tokens.primaryBlue),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _homeGastoMontoCtrl,
                    focusNode: _gastoMontoFocus,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 8, right: 2),
                        child: Text(
                          '\$',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      prefixIconConstraints: BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: tokens.primaryBlue),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: () async {
                    final desc = _homeGastoDescCtrl.text.trim();
                    final monto =
                        double.tryParse(_homeGastoMontoCtrl.text) ?? 0;
                    if (desc.isEmpty || monto <= 0) return;
                    setState(() {
                      _todayGastos.add({'descripcion': desc, 'monto': monto});
                      _homeGastoDescCtrl.clear();
                      _homeGastoMontoCtrl.clear();
                    });
                    await _saveTodayGastos();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                  ),
                  child: Icon(Icons.add, size: 18),
                ),
              ),
            ],
          ),
          // Product gastos — single collapsible "Carga" row
          if (_productGastos.isNotEmpty) ...[
            SizedBox(height: 8),
            GestureDetector(
              onTap: () =>
                  setState(() => _cargaGastoExpanded = !_cargaGastoExpanded),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Carga',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '- \$${_productGastos.fold<double>(0, (s, g) => s + ((g['monto'] as num?)?.toDouble() ?? 0)).toStringAsFixed(0)}',
                    style: TextStyle(
                      color: tokens.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    _cargaGastoExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 16,
                  ),
                ],
              ),
            ),
            if (_cargaGastoExpanded)
              ..._productGastos.map(
                (g) => Padding(
                  padding: EdgeInsets.only(left: 24, top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          g['descripcion'] as String,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '- \$${((g['monto'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: tokens.danger.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (_todayGastos.isNotEmpty) ...[
            SizedBox(height: 8),
            ..._todayGastos.asMap().entries.map((entry) {
              final i = entry.key;
              final g = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        g['descripcion'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '- \$${((g['monto'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: tokens.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6),
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: tokens.surface2,
                            title: Text(
                              'Eliminar gasto',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            content: Text(
                              '¿Eliminar "${g['descripcion']}" (\$${((g['monto'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)})?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  'Eliminar',
                                  style: TextStyle(color: tokens.danger),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          setState(() => _todayGastos.removeAt(i));
                          await _saveTodayGastos();
                        }
                      },
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRecaudadoCard() {
    final value = _showStats ? _formatMoney(_liveRecaudado) : '—';
    final ultimaVez = _ultimaVezRecaudado > 0
        ? 'Última vez: ${_formatMoney(_ultimaVezRecaudado)}'
        : 'Última vez: —';
    final deuda = _showStats && _liveDeudaTotal != 0
        ? 'Deuda de hoy: ${_formatMoney(_liveDeudaTotal)}'
        : 'Deuda de hoy: —';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payments_outlined, color: Colors.white54, size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'RECAUDADO',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 3),
          Text(
            ultimaVez,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
          SizedBox(height: 1),
          Text(
            deuda,
            style: TextStyle(
              color: _showStats && _liveDeudaTotal > 0
                  ? tokens.danger.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTiempoFaltanteCard() {
    String value;
    String ultimaVezStr;

    if (_isRecorridoForCurrentReparto && _ultimaVezDuracion > 0) {
      final remaining = _ultimaVezDuracion - _currentElapsed.inSeconds;
      if (remaining >= 0) {
        value = _formatDuration(Duration(seconds: remaining));
      } else {
        value = '+${_formatDuration(Duration(seconds: -remaining))}';
      }
      ultimaVezStr =
          'Última vez: ${_formatDuration(Duration(seconds: _ultimaVezDuracion))}';
    } else if (_isRecorridoForCurrentReparto) {
      value = _formatDuration(_currentElapsed);
      ultimaVezStr = 'Última vez: —';
    } else {
      final bigDuration = _todayDuracion > 0
          ? _todayDuracion
          : _ultimaVezDuracion;
      value = bigDuration > 0
          ? _formatDuration(Duration(seconds: bigDuration))
          : '—';
      ultimaVezStr = _ultimaVezDuracion > 0
          ? 'Última vez: ${_formatDuration(Duration(seconds: _ultimaVezDuracion))}'
          : 'Última vez: —';
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, color: Colors.white54, size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'TIEMPO FALTANTE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color:
                    _isRecorridoForCurrentReparto &&
                        _ultimaVezDuracion > 0 &&
                        _currentElapsed.inSeconds > _ultimaVezDuracion
                    ? tokens.danger
                    : Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            ultimaVezStr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildRankingItem(int rank, String name, int units, int maxUnits) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Row(
        children: [
          Text(
            '$rank',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                name,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white10,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (units / maxUnits).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: tokens.primaryBlue,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Text(
            '${units}u',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  List<Widget> _buildRankingList() {
    final nonZero = _rankedProducts.where((p) => p.quantity > 0).toList();
    final items = _showAllRanking
        ? _rankedProducts
        : (nonZero.length > 3 ? nonZero.sublist(0, 3) : nonZero);

    if (items.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No hay entregas registradas',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ),
      ];
    }

    final maxQty = items.fold<int>(
      0,
      (m, p) => p.quantity > m ? p.quantity : m,
    );
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) widgets.add(SizedBox(height: 8));
      widgets.add(
        _buildRankingItem(
          i + 1,
          items[i].name,
          items[i].quantity,
          maxQty > 0 ? maxQty : 1,
        ),
      );
    }
    return widgets;
  }

  // ignore: unused_element
  Widget _buildSectionHeader(
    String title,
    String subtitle, {
    bool showVerTodo = false,
    VoidCallback? onVerTodo,
  }) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          '·  $subtitle',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
        Spacer(),
        if (showVerTodo)
          GestureDetector(
            onTap: onVerTodo,
            child: Text(
              _showAllRanking ? 'Ver menos' : 'Ver todo',
              style: TextStyle(
                color: tokens.primaryBlue,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    VoidCallback? onSelect,
  }) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _currentIndex = index);
          onSelect?.call();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon pill — light blue tint when active, transparent otherwise.
              Container(
                width: 56,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive
                      ? tokens.primaryBlue.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isActive ? tokens.primaryBlue : tokens.textMuted,
                  size: 22,
                ),
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? tokens.primaryBlue : tokens.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankedProduct {
  final String name;
  final int quantity;
  _RankedProduct({required this.name, required this.quantity});
}

/// Compact line+area sparkline. Renders a polyline through normalized
/// points with a soft gradient fill below and a dot on the most recent
/// value. Mirrors the web Finanzas `_SparkLine` widget.
class _MiniSparkLinePainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _MiniSparkLinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.fold<int>(0, (m, v) => v > m ? v : m);
    if (maxVal == 0) {
      // Flat baseline
      final paint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, size.height - 1),
        Offset(size.width, size.height - 1),
        paint,
      );
      return;
    }

    final n = values.length;
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : (i / (n - 1)) * size.width;
      final y = size.height - 2 - (values[i] / maxVal) * (size.height - 6);
      points.add(Offset(x, y));
    }

    // Gradient fill under the curve
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke
    final strokePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      strokePath.lineTo(points[i].dx, points[i].dy);
    }
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(strokePath, strokePaint);

    // Dot at the most recent (rightmost) point
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(points.last, 2.6, dotPaint);
  }

  @override
  bool shouldRepaint(_MiniSparkLinePainter old) =>
      old.values != values || old.color != color;
}
