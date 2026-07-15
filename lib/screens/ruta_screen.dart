import 'dart:async';
import 'dart:convert';
import 'dart:math' show cos, sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/platform_file_helper.dart';
import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../widgets/onboarding/tutorial_controller.dart';
import '../widgets/onboarding/guided_tutorial_overlay.dart';
import '../services/afip_service.dart';
import '../services/auth_service.dart';
import '../services/invoice_pdf_service.dart';
import '../services/mercadopago_service.dart';
import '../services/secure_credentials.dart';
import '../services/sync_service.dart';
import '../utils/argentina_time.dart';
import '../utils/app_tokens.dart';
import '../utils/factura_guards.dart';
import '../utils/money.dart';
import '../utils/pack_format.dart';
import '../utils/parse_number.dart';
import '../utils/payment_edit_policy.dart';
import 'clientes_screen.dart';
// ignore: unused_import
import 'facturas_screen.dart';

class RutaScreen extends StatefulWidget {
  final int? repartoId;
  final String? repartoNombre;
  final int? selectedDay;
  final String? activeSemana;
  final int refreshTrigger;

  /// Callback for live stats: (clientesVisited, clientesTotal, productosBought, recaudado, deudaTotal, hasDeferredWithPayment)
  final void Function(int, int, int, double, double, bool)? onStatsChanged;

  const RutaScreen({
    super.key,
    this.repartoId,
    this.repartoNombre,
    this.selectedDay,
    this.activeSemana,
    this.refreshTrigger = 0,
    this.onStatsChanged,
  });

  @override
  State<RutaScreen> createState() => _RutaScreenState();
}

class _CrossDayClienteMatch {
  final Cliente cliente;
  final int day;

  _CrossDayClienteMatch({required this.cliente, required this.day});
}

class _RutaScreenState extends State<RutaScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  AppTokens get tokens => AppTokens.of(context);
  static const double _arBoundsLatMin = -56.0;
  static const double _arBoundsLatMax = -21.0;
  static const double _arBoundsLngMin = -74.0;
  static const double _arBoundsLngMax = -53.0;

  // Deterministic color pool for etiquetas (same as clientes_screen)
  static const List<Color> _tagColors = [
    Color(0xFF1292D3),
    Color(0xFF2ECC71),
    Color(0xFFE67E22),
    Color(0xFF9B59B6),
    Color(0xFFE74C3C),
    Color(0xFF1ABC9C),
    Color(0xFFF1C40F),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF8BC34A),
    Color(0xFFFF5722),
    Color(0xFF3F51B5),
  ];

  Map<String, Color> _customEtiquetaColors = {};

  Color _colorForEtiqueta(String etiqueta) {
    final key = etiqueta.toLowerCase().trim();
    if (_customEtiquetaColors.containsKey(key))
      return _customEtiquetaColors[key]!;
    final hash = key.hashCode;
    return _tagColors[hash.abs() % _tagColors.length];
  }

  static List<String> _parseEtiquetas(String etiqueta) {
    if (etiqueta.isEmpty) return [];
    return etiqueta
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _frecLetter(String frecuencia) {
    switch (frecuencia.toLowerCase()) {
      case 'semanal':
        return 'S';
      case 'quincenal':
        return 'Q';
      case 'mensual':
        return 'M';
      default:
        return '?';
    }
  }

  static String _geocodeAddressKey(String address) =>
      address.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static bool _isWithinArgentinaBounds(double lat, double lng) =>
      lat >= _arBoundsLatMin &&
      lat <= _arBoundsLatMax &&
      lng >= _arBoundsLngMin &&
      lng <= _arBoundsLngMax;

  final _db = AppDatabase.instance;
  final _searchController = TextEditingController();

  List<Cliente> _clientes = [];
  List<Cliente> _filteredClientes = [];
  final Map<int, List<Cliente>> _crossDayClienteCache = {};
  final Map<int, Future<List<Cliente>>> _crossDayClienteFetches = {};
  List<_CrossDayClienteMatch> _crossDayMatches = [];
  int _crossDaySearchGeneration = 0;
  // ignore: unused_field
  Map<int, List<ClienteProducto>> _clienteProducts = {};
  Map<int, Map<int, Entrega>> _clienteEntregas = {};
  Map<int, Pago?> _clientePagos = {};
  final Map<int, Future<Object?>> _pagoOpQueue = {};

  Future<T> _runQueuedPagoOp<T>(int clienteId, Future<T> Function() op) async {
    final previous = _pagoOpQueue[clienteId];
    Future<T> run() async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      return op();
    }

    final runFuture = run();
    final queueFuture = runFuture.then<Object?>((_) => null);
    _pagoOpQueue[clienteId] = queueFuture;
    try {
      return await runFuture;
    } finally {
      if (identical(_pagoOpQueue[clienteId], queueFuture)) {
        _pagoOpQueue.remove(clienteId);
      }
    }
  }

  // Issue 1: deferred-commit model. Qty +/- on a NOT-yet-committed cliente
  // updates _clienteEntregas in-memory only (no DB write, no CC change). The
  // first payment chip / status chip tap commits all drafts atomically with
  // the pago. After commit, qty edits write through (UPDATE the day's row).
  // _committedToday is hydrated in _loadData from existing DB state — so
  // upgrades from v30 mid-recorrido don't lose committed work.
  final Set<int> _draftClienteIds = {};
  final Set<int> _committedToday = {};
  Map<int, Producto> _productMap = {};
  Map<int, Producto> _productMapIncludingDeleted = {};
  List<Producto> _allProducts = [];
  List<Producto> _allProductsIncludingDeleted = [];
  // productoId -> list of price types
  Map<int, List<ProductoPrecio>> _productPrices = {};
  // clienteId -> { productoId -> precioTipoId }
  Map<int, Map<int, int?>> _clientePrecioSelections = {};
  // Carga for current day: productoId -> cantidad loaded in truck
  Map<int, int> _cargaForDay = {};

  bool _mapExpanded = false;

  // clienteId -> 'pending' | 'completed' | 'skipped'
  final Map<int, String> _clienteStatus = {};
  bool _statusesRestored = false; // only restore statuses on first load
  int _localWriteCount =
      0; // guard to skip onDataChanged reload during own writes
  // Reorder persist coalescing: the full desired {clienteId: orden} mapping,
  // captured synchronously at call time; a single runner drains it so rapid
  // drags never interleave writes (see _persistClientOrder).
  Map<int, int>? _pendingOrdenWrite;
  bool _persistOrderRunning = false;
  Timer? _midnightTimer;

  // Scoped to the cliente panel (modal bottom sheet) so SnackBars render
  // above the sheet instead of behind it at the root Scaffold's bottom.
  final GlobalKey<ScaffoldMessengerState> _sheetMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // --- Filter state ---
  // Status filter: 'todos', 'pendientes', 'listos', 'cobrados', 'deudores'
  String _statusFilter = 'todos';
  // Sort: 'numero', 'cercania'
  String _sortMode = 'numero';
  bool _editMode = false;
  bool _markingMode = false;
  AnimationController? _shakeController;
  // Frequency toggles
  bool _showSemanal = true;
  bool _showQuincenal = true;
  bool _showMensual = true;
  // Etiqueta filter (empty = show all)
  Set<String> _selectedEtiquetas = {};
  Set<String> _repartoEtiquetas = {};
  Set<int> _markedClienteIds = {};
  // Productos with a configured pack_size (productId -> pack size).
  // Used to pack-adjust qty displays in EN POSESIÓN chips so they read
  // in pack counts. Storage stays in unit counts; this is a display
  // transform only.
  Map<int, int> _productPackSizes = {};

  // Persistent monto controllers for inline payment (keyed by clienteId)
  final Map<int, TextEditingController> _inlineMontoControllers = {};
  final Map<int, FocusNode> _inlineMontoFocusNodes = {};
  final Set<int> _manuallyEditedMonto = {};
  final Map<int, String> _editingPagoMethods = {};
  final Set<int> _inlineMontoFocusListenerIds = {};
  // Pagos creados de forma provisional al tipear el monto (onChanged / commit
  // por blur), todavía sin un tap explícito de método. Un re-tap del método ya
  // activo sobre uno de estos es una FINALIZACIÓN (auto-Listo), no un
  // "deshacer": _setPago los marca, el tap explícito y _removePago los limpian.
  final Set<int> _provisionalPagoClientes = {};

  // Manually toggled expanded client. null = use auto-computed active client.
  // -1 = force all collapsed (user collapsed the auto-active one).
  int? _expandedClienteId;

  // Top 3 most-ordered products per client (last 3 months)
  Map<int, List<int>> _clientTopProducts = {};

  LatLng? _currentLocation;
  GoogleMapController? _mapController;
  bool _mapEnabled = true;
  bool _mapPreferenceHydrated = false;
  bool _qrEnabled = true;
  bool _mapFallbackCameraApplied = false;
  Set<String> _vistaRapidaFields = AppDatabase.defaultVistaRapidaFields.toSet();

  // Geocoded client locations & map markers
  final Map<int, LatLng> _geocodedLocations = {};
  final Map<int, String> _geocodedAddressKeys = {};
  Set<Marker> _clientMarkers = {};
  Set<Polyline> _routePolylines = {};
  int? _miniCardClienteId;
  StreamSubscription<Position>? _positionStreamSub;
  // Driving duration cache: clientId -> duration in seconds from current location
  final Map<int, int> _drivingDurations = {};
  // Phase 3: tracked for the static map preview's "Cargando mapa…" placeholder
  // so the sodero sees something while addresses are being geocoded for the
  // first time.
  bool _geocodingRunning = false;

  // Scroll/highlight support for the tap-the-number "mover cliente" shortcut
  // in Personalizado mode. _listScrollController drives the cliente list
  // (both the plain ListView and ReorderableListView paths), _cardKeys
  // hooks into each rendered card so Scrollable.ensureVisible can fine-tune
  // the scroll after a jump, and _highlightedClienteId paints a brief glow
  // on the moved card so the sodero can see what landed where.
  final ScrollController _listScrollController = ScrollController();
  final Map<int, GlobalKey> _listCardKeys = {};

  // Spotlight targets for the guided tutorial (Ruta walkthrough steps 22-26).
  final GlobalKey _kRutaToggle = GlobalKey();
  final GlobalKey _kRutaFilter = GlobalKey();
  int? _movedHighlightId;
  Timer? _movedHighlightTimer;

  // Warns the sodero if they start anotando entregas/pagos before tapping
  // "Empezar reparto" — easy to forget when grabbing the phone in a hurry.
  // Acknowledged once per active screen session; reset on reparto transitions
  // so a later sign-out / fresh recorrido re-arms the gate.
  bool _noRepartoWarningAcked = false;

  // One-shot custom price per cliente/product for the current day's
  // recorrido. Lets the sodero charge a non-standard price (e.g. "today
  // this cliente paid $1500 instead of the regular $1800") without having
  // to create + later delete a new price type. The price travels onto the
  // entrega via the existing precio_unitario snapshot, so once written
  // there's nothing to clean up. Cleared on day/reparto change.
  // Shape: clienteId -> productoId -> price
  final Map<int, Map<int, double>> _overridePrices = {};
  final Set<String> _manualPriceWritesInFlight = {};
  Future<bool>? _noRepartoWarningInFlight;
  late final void Function() _dbDataListener = _handleDbDataChanged;
  late final void Function() _localDbDataListener = _handleLocalDbDataChanged;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shakeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _loadData();
    _loadSettings();
    _getCurrentLocation();
    _searchController.addListener(_filterClientes);
    _scheduleMidnightReset();
    // Listen for DB changes (e.g. cloud restore) to reload clients. Registered
    // as independent listeners so Home/Ruta do not overwrite each other.
    _db.addDataListener(_dbDataListener);
    _db.addLocalDataListener(_localDbDataListener);
  }

  void _hydrateVisibleMapModeOnce(bool mapEnabled) {
    if (_mapPreferenceHydrated) return;
    _mapExpanded = mapEnabled;
    _mapPreferenceHydrated = true;
  }

  Future<void> _loadSettings() async {
    final map = await _db.getMapEnabled();
    final qr = await _db.getQrEnabled();
    final vista = await _db.getVistaRapidaFields();
    if (mounted) {
      setState(() {
        _mapEnabled = map;
        // Hydrate the visible Lista/Mapa mode once from the persisted
        // preference. After that, reloads must not force the user back to
        // Mapa/Lista while they are working through clients.
        _hydrateVisibleMapModeOnce(map);
        _qrEnabled = qr;
        _vistaRapidaFields = vista;
      });
    }
  }

  /// Safely animate camera — catches errors from disposed controllers.
  void _safeAnimateCamera(CameraUpdate update) {
    try {
      _mapController?.animateCamera(update);
    } catch (_) {
      // Controller may have been disposed during map transition
    }
  }

  LatLng _mapInitialTarget() {
    if (_currentLocation != null) return _currentLocation!;

    final activeId = _miniCardClienteId ?? _activeClienteId;
    if (activeId != null) {
      final activeLoc = _geocodedLocations[activeId];
      if (activeLoc != null) return activeLoc;
    }

    for (final c in _filteredClientes) {
      final loc = _geocodedLocations[c.id];
      if (loc != null) return loc;
    }

    if (_geocodedLocations.isNotEmpty) return _geocodedLocations.values.first;

    // Simulator-safe fallback. The real device path still replaces this with
    // the driver's location as soon as Geolocator returns a fix.
    return const LatLng(-34.6037, -58.3816);
  }

  double _mapInitialZoom() {
    if (_currentLocation != null) return 15;
    if (_miniCardClienteId != null || _activeClienteId != null) return 15;
    if (_geocodedLocations.isNotEmpty) return 13;
    return 11;
  }

  void _focusMapOnFallbackIfNeeded() {
    if (_mapFallbackCameraApplied || !_mapExpanded || _mapController == null) {
      return;
    }
    if (_currentLocation != null) {
      _mapFallbackCameraApplied = true;
      return;
    }

    final target = _mapInitialTarget();
    _mapFallbackCameraApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapExpanded) return;
      _safeAnimateCamera(CameraUpdate.newLatLngZoom(target, _mapInitialZoom()));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Issue 1: on resume, refresh ONLY the currently-expanded cliente's CC
    // (if any). Bulk-refreshing the whole reparto on resume was a major lag
    // source in v37 — single-cliente refresh is what the user actually sees.
    if (state == AppLifecycleState.resumed && _expandedClienteId != null) {
      _refreshClienteCuentaCorriente(_expandedClienteId!);
    }
  }

  /// Issue 1: targeted single-cliente refresh of cuenta_corriente. Reads ONE
  /// cliente row (cheap) and patches it into _clientes / _filteredClientes
  /// in place so the Deudor pill stays in sync with the DB. Do NOT bulk
  /// refresh — that's the lag pattern.
  Future<void> _refreshClienteCuentaCorriente(int clienteId) async {
    final fresh = await _db.getCliente(clienteId);
    if (fresh == null || !mounted) return;
    setState(() {
      final i = _clientes.indexWhere((c) => c.id == clienteId);
      if (i >= 0) _clientes[i] = fresh;
      final j = _filteredClientes.indexWhere((c) => c.id == clienteId);
      if (j >= 0) _filteredClientes[j] = fresh;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSub?.cancel();
    _midnightTimer?.cancel();
    _db.removeDataListener(_dbDataListener);
    _db.removeLocalDataListener(_localDbDataListener);
    _shakeController?.dispose();
    _searchController.dispose();
    _listScrollController.dispose();
    _movedHighlightTimer?.cancel();
    _mapController?.dispose();
    for (final c in _inlineMontoControllers.values) {
      c.dispose();
    }
    for (final f in _inlineMontoFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _handleDbDataChanged() {
    // Skip reload when this screen is making writes — _updateEntrega / _setPago
    // already do their own targeted setState. Reloading here would race and
    // overwrite the fresh state with stale data.
    //
    // P3.4 Issue B: also skip reload while drafts exist. _loadData reads from
    // DB and overwrites _clienteEntregas, which would silently wipe pending qty
    // edits the sodero has not committed yet. Drafts win over sync — the
    // listener catches up after the next commit.
    if (mounted && _localWriteCount == 0 && _draftClienteIds.isEmpty) {
      _loadData();
    }
    // Settings change independently of data (e.g. user toggles auto-Listo in
    // Configuración while Ruta sits in the IndexedStack underneath).
    if (mounted) {
      _loadSettings();
    }
  }

  void _handleLocalDbDataChanged() {
    if (mounted && _localWriteCount == 0 && _draftClienteIds.isEmpty) {
      _loadData();
    }
  }

  /// Return the global rect of the widget owning [ctx], used as the iPad
  /// share-sheet popover anchor. Falls back to a tiny rect at screen center.
  Rect? _rectFromContext(BuildContext ctx) {
    try {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return null;
      final origin = box.localToGlobal(Offset.zero);
      return origin & box.size;
    } catch (_) {
      return null;
    }
  }

  /// Wipe in-memory and persisted per-client statuses when the Argentine
  /// calendar day rolls over while this screen is open.
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = argentinaTime();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: 1, seconds: 1));
    _midnightTimer = Timer(next.difference(now), () async {
      if (!mounted) return;
      _clienteStatus.clear();
      _overridePrices.clear();
      _statusesRestored = true;
      final rId = widget.repartoId;
      final day = widget.selectedDay;
      if (rId != null) {
        try {
          // v85: day-scoped — with «Instancias», another day of the SAME
          // reparto may still be running on this account; the midnight
          // reset of THIS screen's day must not wipe that recorrido.
          if (day != null) {
            await _db.clearRecorridoForRepartoAndDay(rId, day);
          } else {
            await _db.clearRecorridoForReparto(rId);
          }
        } catch (_) {}
      }
      if (mounted) setState(() {});
      await _loadData();
      _scheduleMidnightReset();
    });
  }

  @override
  void didUpdateWidget(covariant RutaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repartoId != widget.repartoId ||
        oldWidget.selectedDay != widget.selectedDay) {
      // A different day or reparto starts fresh — drop any one-shot
      // manual prices the sodero set up for the previous combination.
      _overridePrices.clear();
      _clearCrossDaySearchCache();
      _loadData();
    } else if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      if (_mapExpanded) {
        setState(() => _mapExpanded = false);
      }
      _loadData();
    }
    // When recorrido starts (callback goes from null to non-null), reset & emit.
    // Also fires on app restart once HomeScreen hydrates _repartoConfirmed —
    // we must re-run the restore path so the pagos-backed statuses survive
    // (otherwise the previously-populated _clienteStatus map gets wiped here
    // and _loadData skips the restore because _statusesRestored is already
    // true).
    if (oldWidget.onStatsChanged == null && widget.onStatsChanged != null) {
      _clienteStatus.clear();
      _statusesRestored = false;
      _loadData();
    }
    // Re-arm the "anotar sin empezar reparto" warning whenever the reparto
    // toggle flips in either direction. A fresh start of work should ask
    // again so the sodero doesn't carry over an old acknowledgement.
    if (oldWidget.onStatsChanged != widget.onStatsChanged) {
      _noRepartoWarningAcked = false;
    }
  }

  /// Lightweight reload of just product prices and selections (no full _loadData)
  // ignore: unused_element
  Future<void> _refreshPrices() async {
    final allProducts = await _db.getAllProducts(widget.repartoId!);
    final allProductsIncludingDeleted = await _db
        .getAllProductsIncludingDeleted(widget.repartoId!);
    final allPP = await _db.getAllProductoPrecios(widget.repartoId!);
    final ppMap = <int, List<ProductoPrecio>>{};
    for (final pp in allPP) {
      ppMap.putIfAbsent(pp.productoId, () => []).add(pp);
    }
    // Reload client price selections
    final precioSelections = <int, Map<int, int?>>{};
    for (final c in _clientes) {
      final cps = await _db.getClienteProductos(c.id);
      final selMap = <int, int?>{};
      for (final cp in cps) {
        selMap[cp.productoId] = cp.precioTipoId;
      }
      precioSelections[c.id] = selMap;
    }
    if (mounted) {
      setState(() {
        _allProducts = allProducts;
        _allProductsIncludingDeleted = allProductsIncludingDeleted;
        _productMap = {for (final p in allProducts) p.id: p};
        _productMapIncludingDeleted = {
          for (final p in allProductsIncludingDeleted) p.id: p,
        };
        _productPrices = ppMap;
        _clientePrecioSelections = precioSelections;
      });
    }
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

  String _mpAccessToken = '';

  int get _currentDay {
    if (widget.selectedDay != null) return widget.selectedDay!;
    final weekday = argentinaTime().weekday;
    return weekday >= 1 && weekday <= 7 ? weekday - 1 : 0;
  }

  String get _currentSemana => widget.activeSemana ?? argentinaWeekString();

  String get _dayNameForCurrentDay {
    final day = _currentDay;
    return day >= 0 && day < _allDayNames.length ? _allDayNames[day] : '';
  }

  String _shortDayName(int day) {
    if (day < 0 || day >= _allDayNames.length) return '?';
    final name = _allDayNames[day];
    return name.length <= 3 ? name : name.substring(0, 3);
  }

  List<int> _crossDayOrder(int selectedDay) {
    return List.generate(5, (i) => (selectedDay + 1 + i) % 6);
  }

  bool _matchesClienteSearch(Cliente cliente, String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    return cliente.nombre.toLowerCase().contains(q) ||
        cliente.direccion.toLowerCase().contains(q) ||
        cliente.telefono.toLowerCase().contains(q);
  }

  void _clearCrossDaySearchCache() {
    _crossDaySearchGeneration++;
    _crossDayClienteCache.clear();
    _crossDayClienteFetches.clear();
    _crossDayMatches = [];
  }

  Future<void> _loadMarkedClientes() async {
    final marked = await _db.getMarkedClientesForWeek(_currentSemana);
    if (!mounted) return;
    setState(() => _markedClienteIds = marked);
  }

  Future<void> _toggleClienteMark(Cliente cliente) async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    final semana = _currentSemana;
    if (_markedClienteIds.contains(cliente.id)) {
      await _db.clearClienteMark(cliente.id);
      if (!mounted) return;
      setState(() => _markedClienteIds.remove(cliente.id));
    } else {
      await _db.setClienteMarked(cliente.id, semana);
      if (!mounted) return;
      setState(() => _markedClienteIds.add(cliente.id));
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(
          () =>
              _currentLocation = LatLng(position.latitude, position.longitude),
        );
      }

      // Start position stream for geofencing
      _positionStreamSub ??=
          Geolocator.getPositionStream(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
            ),
          ).listen((Position pos) {
            if (!mounted) return;
            final newLoc = LatLng(pos.latitude, pos.longitude);
            setState(() => _currentLocation = newLoc);
            _checkGeofence(newLoc);
          });
    } catch (_) {}
  }

  void _checkGeofence(LatLng driverLocation) {
    if (!_mapExpanded) return;

    for (final c in _clientes) {
      final loc = _geocodedLocations[c.id];
      if (loc == null) continue;
      final status = _getClientStatus(c.id);
      if (status != 'pending') continue;

      final distance = Geolocator.distanceBetween(
        driverLocation.latitude,
        driverLocation.longitude,
        loc.latitude,
        loc.longitude,
      );

      if (distance <= 200 && _miniCardClienteId != c.id) {
        setState(() => _miniCardClienteId = c.id);
        if (_mapController != null) {
          _safeAnimateCamera(CameraUpdate.newLatLngZoom(loc, 17));
        }
        return;
      }
    }
  }

  Future<void> _loadData() async {
    if (widget.repartoId == null) return;
    final repartoId = widget.repartoId!;
    final semana = _currentSemana;
    final day = _currentDay;

    final allProducts = await _db.getAllProducts(repartoId);
    final allProductsIncludingDeleted = await _db
        .getAllProductsIncludingDeleted(repartoId);
    final productMap = {for (final p in allProducts) p.id: p};
    final productMapIncludingDeleted = {
      for (final p in allProductsIncludingDeleted) p.id: p,
    };
    final carga = await _db.getCargaForDay(repartoId, day, semana);

    final clients = await _db.getClientesForRepartoDay(repartoId, day);
    final allRepartoClientes = await _db.getClientesForReparto(repartoId);
    final etiquetas = <String>{};
    for (final c in allRepartoClientes) {
      etiquetas.addAll(_parseEtiquetas(c.etiqueta));
    }
    final packSizes = await _db.getProductoPackSizesForReparto(repartoId);
    await _loadMarkedClientes();

    final cpMap = await _db.getClienteProductosForRepartoDay(repartoId, day);
    final entregasMap = await _db.getEntregasForRepartoDayByCliente(
      repartoId,
      semana,
      day,
    );
    final pagoRows = await _db.getPagosForRepartoDayByCliente(
      repartoId,
      semana,
      day,
    );
    final pagosMap = <int, Pago?>{};

    // Load all product prices
    final allPP = await _db.getAllProductoPrecios(repartoId);
    final ppMap = <int, List<ProductoPrecio>>{};
    for (final pp in allPP) {
      ppMap.putIfAbsent(pp.productoId, () => []).add(pp);
    }

    final precioSelections = <int, Map<int, int?>>{};

    for (final c in clients) {
      final cps = cpMap[c.id] ?? const <ClienteProducto>[];
      cpMap[c.id] = cps;
      // Build price selection map for this client
      final selMap = <int, int?>{};
      for (final cp in cps) {
        selMap[cp.productoId] = cp.precioTipoId;
      }
      precioSelections[c.id] = selMap;
      entregasMap.putIfAbsent(c.id, () => <int, Entrega>{});
      pagosMap[c.id] = pagoRows[c.id];
    }

    // Load custom etiqueta colors
    final customColors = <String, Color>{};
    try {
      final colorEntries = await _db.getEtiquetaColors(repartoId);
      for (final e in colorEntries) {
        customColors[e.nombre.toLowerCase().trim()] = Color(
          int.parse(e.colorHex, radix: 16),
        );
      }
    } catch (_) {}

    // Load settings
    final mapEnabled = await _db.getMapEnabled();
    final qrEnabled = await _db.getQrEnabled();
    final vistaFields = await _db.getVistaRapidaFields();
    // P0-4b: the MP token lives in the Keystore, not the DB.
    final mpToken = await SecureCredentials.instance.readMpToken();

    // Restore client statuses ONLY on first load (app start / screen init).
    // Subsequent reloads (from onDataChanged after user actions) must NOT
    // override in-session status — the worker decides status manually.
    if (!_statusesRestored) {
      _statusesRestored = true;
      // First try to restore from persisted recorrido state (survives app kill)
      try {
        final rId = widget.repartoId;
        if (rId != null && widget.selectedDay != null) {
          // Try new multi-recorrido format first
          final savedList = await _db.getActiveRecorridos();
          String statusesJson = '';
          for (final entry in savedList) {
            if (entry['repartoId'] == rId &&
                entry['day'] == widget.selectedDay) {
              statusesJson = (entry['clientStatuses'] as String?) ?? '';
              break;
            }
          }
          // Fallback: try legacy single-recorrido format
          if (statusesJson.isEmpty) {
            final legacy = await _db.getRecorridoState();
            if (legacy != null && legacy['repartoId'] == rId) {
              statusesJson = (legacy['clientStatuses'] as String?) ?? '';
            }
          }
          if (statusesJson.isNotEmpty) {
            final decoded = jsonDecode(statusesJson) as Map<String, dynamic>;
            for (final entry in decoded.entries) {
              final id = int.tryParse(entry.key);
              if (id != null && entry.value is String) {
                _clienteStatus[id] = entry.value as String;
              }
            }
          }
        }
      } catch (_) {}
      // Then fill in any missing statuses from pagos (normal restore path)
      for (final c in clients) {
        if (_clienteStatus.containsKey(c.id)) continue;
        final pago = pagosMap[c.id];
        if (pago != null) {
          if (pago.metodoPago == 'no_compro') {
            _clienteStatus[c.id] = 'skipped';
          } else if (pago.metodoPago == 'ausente') {
            _clienteStatus[c.id] = 'absent';
          } else if ({
            'efectivo',
            'transferencia',
            'no_pago',
          }.contains(pago.metodoPago)) {
            _clienteStatus[c.id] = 'completed';
          }
        }
      }
    }

    // Issue 1: hydrate _committedToday from DB state. A cliente is "committed
    // today" if they already have a pago row OR any entrega with entregado>0
    // for (today's semana, today's day). Anything else is a draft — qty edits
    // stay in-memory until the first payment / status chip tap.
    final committedToday = <int>{};
    for (final c in clients) {
      final hasPago = pagosMap.containsKey(c.id);
      final hasNonZeroEntrega = (entregasMap[c.id] ?? <int, Entrega>{}).values
          .any((e) => e.entregado > 0);
      if (hasPago || hasNonZeroEntrega) committedToday.add(c.id);
    }

    if (mounted) {
      setState(() {
        _productMap = productMap;
        _productMapIncludingDeleted = productMapIncludingDeleted;
        _allProducts = allProducts;
        _allProductsIncludingDeleted = allProductsIncludingDeleted;
        _productPrices = ppMap;
        _clientePrecioSelections = precioSelections;
        _clientes = clients;
        _repartoEtiquetas = etiquetas;
        _productPackSizes = packSizes;
        _filteredClientes = _applyFilters(clients);
        final activeIds = clients.map((c) => c.id).toSet();
        _listCardKeys.removeWhere((id, _) => !activeIds.contains(id));
        _clienteProducts = cpMap;
        _clienteEntregas = entregasMap;
        _clientePagos = pagosMap;
        _cargaForDay = carga;
        _customEtiquetaColors = customColors;
        _mapEnabled = mapEnabled;
        _hydrateVisibleMapModeOnce(mapEnabled);
        _qrEnabled = qrEnabled;
        _vistaRapidaFields = vistaFields;
        _mpAccessToken = mpToken;
        _committedToday
          ..clear()
          ..addAll(committedToday);
        _draftClienteIds.removeWhere((id) => committedToday.contains(id));
      });
      _emitStats();
      if (_mapEnabled) {
        // Hydrate from the persisted cache first (instant — local SELECT),
        // then kick off the geocoder for anything that's still missing or
        // whose address changed since the last geocode. The cached pass
        // means every Ruta open after the first sees markers immediately.
        await _hydrateGeocodedLocationsFromDb();
        _geocodeClients();
      }
      _computeTopProducts(clients);
    }
  }

  /// Pull cached lat/lng from `clientes` into `_geocodedLocations` before
  /// the geocoder runs. Any cliente whose direccion no longer matches the
  /// stored `geocoded_direccion` is left out — `_geocodeClients` will
  /// refresh it. Synchronous from the UI's perspective: one local SELECT.
  Future<void> _hydrateGeocodedLocationsFromDb() async {
    if (widget.repartoId == null) return;
    try {
      final cached = await _db.getClienteGeocodesForReparto(widget.repartoId!);
      // Build a lookup of current direccion per cliente so we can compare
      // against the address the cache was written for.
      final addressById = <int, String>{
        for (final c in _clientes) c.id: _geocodeAddressKey(c.direccion),
      };
      final activeIds = addressById.keys.toSet();
      _geocodedLocations.removeWhere((id, _) => !activeIds.contains(id));
      _geocodedAddressKeys.removeWhere((id, _) => !activeIds.contains(id));
      for (final row in cached) {
        final id = row['id'] as int;
        final cachedAddr = _geocodeAddressKey(
          row['geocoded_direccion'] as String,
        );
        final liveAddr = addressById[id] ?? '';
        if (liveAddr.isEmpty) continue;
        if (cachedAddr != liveAddr) {
          // Address changed since the cache was written — let
          // _geocodeClients refresh it. Don't surface a stale pin.
          _geocodedLocations.remove(id);
          _geocodedAddressKeys.remove(id);
          continue;
        }
        final lat = row['lat'] as double;
        final lng = row['lng'] as double;
        if (!_isWithinArgentinaBounds(lat, lng)) {
          _geocodedLocations.remove(id);
          _geocodedAddressKeys.remove(id);
          continue;
        }
        _geocodedLocations[id] = LatLng(lat, lng);
        _geocodedAddressKeys[id] = liveAddr;
      }
      _buildClientMarkers();
    } catch (e) {
      debugPrint('[Ruta] Hydrating geocode cache failed: $e');
    }
  }

  /// Compute top 3 most-ordered products per client from the last ~3 months.
  /// Only includes products enabled in habitual product settings.
  Future<void> _computeTopProducts(List<Cliente> clients) async {
    if (widget.repartoId == null) return;
    final now = argentinaTime();
    final threeMonthsAgo = now.subtract(Duration(days: 90));
    final topMap = <int, List<int>>{};

    // Load enabled habitual product IDs
    final enabledIds = await _db.getEnabledHabitualProductIds(
      widget.repartoId!,
    );

    for (final c in clients) {
      final allEntregas = await _db.getAllEntregasForClient(
        c.id,
        widget.repartoId!,
      );
      final freqBought = <int, int>{};
      for (final e in allEntregas) {
        // Parse week string to approximate date for filtering
        // semana format: "YYYY-WNN"
        try {
          final parts = e.semana.split('-W');
          final year = int.parse(parts[0]);
          final week = int.parse(parts[1]);
          final jan1 = DateTime(year, 1, 1);
          final approxDate = jan1.add(
            Duration(days: (week - 1) * 7 + e.diaSemana),
          );
          if (approxDate.isBefore(threeMonthsAgo)) continue;
        } catch (_) {
          continue;
        }
        // Skip products not enabled for habitual display
        if (enabledIds.isNotEmpty && !enabledIds.contains(e.productoId))
          continue;
        if (e.entregado > 0) {
          freqBought[e.productoId] = (freqBought[e.productoId] ?? 0) + 1;
        }
      }
      final sortedBought = freqBought.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topMap[c.id] = sortedBought.take(3).map((e) => e.key).toList();
    }

    if (mounted) {
      setState(() {
        _clientTopProducts = topMap;
      });
    }
  }

  List<Cliente> _applyFilters(List<Cliente> clients) {
    var result = clients.toList();

    // Search filter
    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      result = result.where((c) => _matchesClienteSearch(c, query)).toList();
      if (widget.repartoId != null &&
          widget.selectedDay != null &&
          widget.selectedDay! >= 0) {
        unawaited(_loadCrossDaySearchMatches(query));
      }
    } else {
      _clearCrossDaySearchCache();
    }

    // Frequency filter
    result = result.where((c) {
      final f = c.frecuencia.toLowerCase();
      if (f == 'semanal' && !_showSemanal) return false;
      if (f == 'quincenal' && !_showQuincenal) return false;
      if (f == 'mensual' && !_showMensual) return false;
      return true;
    }).toList();

    // Etiqueta filter
    if (_selectedEtiquetas.isNotEmpty) {
      result = result.where((c) {
        final tags = _parseEtiquetas(c.etiqueta);
        return tags.any((t) => _selectedEtiquetas.contains(t));
      }).toList();
    }

    // Status filter
    if (_statusFilter != 'todos') {
      result = result.where((c) {
        final status = _getClientStatus(c.id);
        final pago = _clientePagos[c.id];
        switch (_statusFilter) {
          case 'pendientes':
            return status == 'pending' || status == 'deferred';
          case 'listos':
            return status == 'completed' ||
                status == 'skipped' ||
                status == 'absent';
          case 'cobrados':
            return pago != null &&
                pago.metodoPago != 'no_pago' &&
                pago.monto > 0;
          case 'deudores':
            return isMoneyNegative(c.cuentaCorriente);
          default:
            return true;
        }
      }).toList();
    }

    // Sort
    if (_sortMode == 'cercania' && _currentLocation != null) {
      result.sort((a, b) {
        final aDur = _drivingDurations[a.id];
        final bDur = _drivingDurations[b.id];
        int cmp;
        if (aDur == null && bDur == null) {
          cmp = 0;
        } else if (aDur == null) {
          return 1; // a sin duración → después de b
        } else if (bDur == null) {
          return -1; // b sin duración → a antes
        } else {
          cmp = aDur.compareTo(bDur);
        }
        // Desempate determinista para que empates de duración no barajen el
        // orden en cada re-sort (List.sort de Dart no es estable).
        if (cmp != 0) return cmp;
        final ordenCmp = a.orden.compareTo(b.orden);
        return ordenCmp != 0 ? ordenCmp : a.id.compareTo(b.id);
      });
    }
    // 'numero' = default order (by orden)

    return result;
  }

  Future<void> _loadCrossDaySearchMatches(String query) async {
    final repartoId = widget.repartoId;
    final selectedDay = widget.selectedDay;
    if (repartoId == null || selectedDay == null || selectedDay < 0) {
      _crossDayMatches = [];
      return;
    }

    final generation = _crossDaySearchGeneration;
    final days = List.generate(
      6,
      (i) => i,
    ).where((day) => day != selectedDay).toList();

    await Future.wait(
      days.map((day) async {
        if (_crossDayClienteCache.containsKey(day)) return;
        final fetch = _crossDayClienteFetches.putIfAbsent(
          day,
          () => _db.getClientesForRepartoDay(repartoId, day),
        );
        try {
          _crossDayClienteCache[day] = await fetch;
        } finally {
          _crossDayClienteFetches.remove(day);
        }
      }),
    );

    if (!mounted ||
        generation != _crossDaySearchGeneration ||
        _searchController.text.toLowerCase().trim() != query) {
      return;
    }

    final matches = <_CrossDayClienteMatch>[];
    for (final day in days) {
      final clients = _crossDayClienteCache[day] ?? <Cliente>[];
      for (final cliente in clients) {
        if (_matchesClienteSearch(cliente, query)) {
          matches.add(_CrossDayClienteMatch(cliente: cliente, day: day));
        }
      }
    }

    setState(() => _crossDayMatches = matches);
  }

  void _onReorderClients(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final item = _filteredClientes.removeAt(oldIndex);
    _filteredClientes.insert(newIndex, item);
    _moveFilteredClientInFullList(item, newIndex);
    setState(() {});
    _persistClientOrder();
  }

  void _moveFilteredClientInFullList(Cliente item, int filteredIndex) {
    final existingIndex = _clientes.indexWhere((c) => c.id == item.id);
    if (existingIndex >= 0) {
      _clientes.removeAt(existingIndex);
    }

    final previousVisible = filteredIndex > 0
        ? _filteredClientes[filteredIndex - 1]
        : null;
    final nextVisible = filteredIndex < _filteredClientes.length - 1
        ? _filteredClientes[filteredIndex + 1]
        : null;

    if (nextVisible != null) {
      final insertIndex = _clientes.indexWhere((c) => c.id == nextVisible.id);
      if (insertIndex >= 0) {
        _clientes.insert(insertIndex, item);
        return;
      }
    }
    if (previousVisible != null) {
      final previousIndex = _clientes.indexWhere(
        (c) => c.id == previousVisible.id,
      );
      if (previousIndex >= 0) {
        _clientes.insert(previousIndex + 1, item);
        return;
      }
    }
    _clientes.insert(0, item);
  }

  /// Persist the current on-screen arrangement as each cliente's `orden`.
  ///
  /// The old per-row loop (`updateClienteOrden` × N, one onDataChanged per
  /// row) let `_loadData` swap `_clientes` mid-loop with a half-persisted
  /// ordering, so the remaining writes baked in the WRONG permutation —
  /// the long-standing "clients randomly change order on load" bug. Now:
  /// the full mapping is snapshotted synchronously (no await before it), a
  /// single runner drains coalesced mappings through ONE atomic DB
  /// transaction each, and `_localWriteCount` suppresses reloads until the
  /// writes are done.
  Future<void> _persistClientOrder() async {
    final day = _currentDay;
    // Snapshot the desired mapping NOW — a mid-persist reload or _clientes
    // swap can't corrupt it. Clientes borrowed into today via a temp-day
    // override keep their HOME day's orden: they pin last on the borrowed
    // day regardless of orden, so writing today's index onto them would
    // only scramble their home day.
    _pendingOrdenWrite = {
      for (var i = 0; i < _clientes.length; i++)
        if (_clientes[i].diaSemana == day) _clientes[i].id: i,
    };
    if (_persistOrderRunning) return; // active runner picks up the mapping
    _persistOrderRunning = true;
    _localWriteCount++; // skip _handleDbDataChanged reloads mid-persist
    var anyChanged = false;
    try {
      while (_pendingOrdenWrite != null) {
        final mapping = _pendingOrdenWrite!;
        _pendingOrdenWrite = null;
        anyChanged = await _db.updateClienteOrdenBatch(mapping) || anyChanged;
      }
    } finally {
      _persistOrderRunning = false;
      _localWriteCount--;
    }
    // One reconciling reload after the guard releases: refreshes the stale
    // in-memory `.orden` fields and applies any sync pull suppressed during
    // the persist. Same conditions as _handleDbDataChanged so drafts and
    // other in-flight guarded writes still win.
    if (anyChanged &&
        mounted &&
        _localWriteCount == 0 &&
        _draftClienteIds.isEmpty) {
      _loadData();
    }
  }

  /// After a tap-the-number reorder, scroll the list to the moved cliente
  /// and glow the card briefly. Two-step scroll (estimated offset jump,
  /// then ensureVisible on the now-built widget) handles the lazy list.
  /// Same UX as the cambiar-día redirect — but here the sodero stays on
  /// the same screen because the move is within the same day.
  void _scrollToAndHighlightInList(int clienteId) {
    final index = _filteredClientes.indexWhere((c) => c.id == clienteId);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScrollController.hasClients) return;
      const estimatedCardHeight = 100.0;
      final maxOffset = _listScrollController.position.maxScrollExtent;
      final target = (index * estimatedCardHeight)
          .clamp(0.0, maxOffset)
          .toDouble();
      _listScrollController.jumpTo(target);
      _ensureVisibleAndHighlightInList(clienteId, retriesRemaining: 2);
    });
  }

  void _ensureVisibleAndHighlightInList(
    int clienteId, {
    required int retriesRemaining,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _listCardKeys[clienteId]?.currentContext;
      if (ctx == null && retriesRemaining > 0) {
        _ensureVisibleAndHighlightInList(
          clienteId,
          retriesRemaining: retriesRemaining - 1,
        );
        return;
      }
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: Duration(milliseconds: 300),
          alignment: 0.2,
          curve: Curves.easeOut,
        );
      }
      setState(() => _movedHighlightId = clienteId);
      _movedHighlightTimer?.cancel();
      _movedHighlightTimer = Timer(Duration(milliseconds: 2500), () {
        if (!mounted) return;
        setState(() => _movedHighlightId = null);
      });
    });
  }

  /// Move a cliente from oldIndex to newIndex0 (both 0-based, final
  /// positions in _filteredClientes). Used by the tap-the-number shortcut.
  /// Mirrors _onReorderClients's _clientes adjustment so filter-aware
  /// ordering stays consistent with what drag-drop produces.
  void _moveClientToPosition(int oldIndex, int newIndex0) {
    if (oldIndex < 0 || oldIndex >= _filteredClientes.length) return;
    if (newIndex0 < 0 || newIndex0 >= _filteredClientes.length) return;
    if (oldIndex == newIndex0) return;
    final item = _filteredClientes.removeAt(oldIndex);
    _filteredClientes.insert(newIndex0, item);
    _moveFilteredClientInFullList(item, newIndex0);
    setState(() {});
    _persistClientOrder();
  }

  /// Personalizado-mode shortcut: tap a cliente's number circle and type
  /// the desired position instead of long-pressing and dragging. Empty /
  /// non-numeric inputs cancel silently. Numbers below 1 or above the
  /// day's cliente count are clamped to the first / last slot.
  Future<void> _showChangePositionDialog(
    Cliente cliente,
    int currentIndex,
  ) async {
    final total = _filteredClientes.length;
    if (total <= 1) return; // nothing meaningful to reorder
    final controller = TextEditingController();
    try {
      final entered = await showDialog<int?>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Mover cliente',
            style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
          ),
          // Scrollable so the keyboard popping over the autofocused field
          // can't cause a RenderFlex overflow on small viewports.
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cliente.nombre}\nPosición actual: ${currentIndex + 1} de $total',
                  style: TextStyle(color: tokens.textSub, fontSize: 13),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(color: tokens.text, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Nueva posición (1 - $total)',
                    hintStyle: TextStyle(
                      color: tokens.textMuted.withValues(alpha: 0.7),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.primaryBlue),
                    ),
                  ),
                  onSubmitted: (val) {
                    final n = int.tryParse(val.trim());
                    Navigator.pop(ctx, n);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
            ),
            TextButton(
              onPressed: () {
                final n = int.tryParse(controller.text.trim());
                Navigator.pop(ctx, n);
              },
              child: Text('Mover', style: TextStyle(color: tokens.primaryBlue)),
            ),
          ],
        ),
      );
      if (entered == null) return; // empty / non-numeric / cancel
      final targetZeroBased = (entered - 1).clamp(0, total - 1);
      _moveClientToPosition(currentIndex, targetZeroBased);
      _scrollToAndHighlightInList(cliente.id);
    } finally {
      // Defer dispose past the dialog's dismiss animation. While the
      // dialog is animating out, a parent setState (from
      // _moveClientToPosition and _persistClientOrder's onDataChanged
      // fan-out) can rebuild the still-mounted TextField against the
      // controller. Disposing synchronously here means that rebuild hits
      // a freed controller and crashes with "TextEditingController used
      // after dispose".
      Future.delayed(Duration(milliseconds: 400), controller.dispose);
    }
  }

  void _filterClientes() {
    setState(() => _filteredClientes = _applyFilters(_clientes));
  }

  // --- Status ---

  /// pending = not yet visited (—), deferred = skipped for now (—), completed = delivered (✓), skipped = didn't buy (✗)
  String _getClientStatus(int clienteId) {
    return _clienteStatus[clienteId] ?? 'pending';
  }

  Future<void> _setClientStatus(int clienteId, String status) async {
    final oldStatus = _clienteStatus[clienteId] ?? 'pending';
    setState(() {
      _clienteStatus[clienteId] = status;
      // Out-of-order edits: do NOT reset _expandedClienteId. The previous
      // reset-to-null forced a snap back to _activeClienteId (always
      // first-pending in filtered order), which prevented the sodero from
      // working downstream clientes without first attending upstream pending
      // ones. Auto-mode users (who never tapped to expand) had
      // _expandedClienteId already null — removing the reset is a no-op for
      // them, the fallback at the card-build site still tracks
      // _activeClienteId. Mirror sites: _clearDeferredStatusForActivity.
    });
    _emitStats();
    _buildClientMarkers();
    // Persist status marker for historial
    await _persistStatusMarker(clienteId, status, oldStatus);
    // Persist client statuses so they survive app kill
    await _persistClientStatuses();
    TutorialController.instance.onEstadoSet();
    // In Mapa mode, mirror Lista's auto-advance: after the sodero marks a
    // cliente Listo / Ausente / Saltado / No compró, jump the mini-card to
    // the next still-pending cliente. The undo case (status='pending')
    // keeps the same cliente focused.
    if (_mapExpanded &&
        status != 'pending' &&
        _miniCardClienteId == clienteId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapExpanded) return;
        _goToNextPendingClient();
      });
    }
  }

  /// Mapa-mode advance: like `_goToNextClient` but skips clientes that
  /// already have a status. Wraps around the filtered list. If no pending
  /// cliente remains (or the next pending has no geocoded location),
  /// closes the mini-card so the sodero sees the empty state.
  void _goToNextPendingClient() {
    if (_filteredClientes.isEmpty) return;
    final count = _filteredClientes.length;
    int currentIdx = -1;
    if (_miniCardClienteId != null) {
      currentIdx = _filteredClientes.indexWhere(
        (c) => c.id == _miniCardClienteId,
      );
    }
    for (var i = 1; i <= count; i++) {
      final idx = (currentIdx + i) % count;
      final c = _filteredClientes[idx];
      if (_getClientStatus(c.id) != 'pending') continue;
      setState(() => _miniCardClienteId = c.id);
      final loc = _geocodedLocations[c.id];
      if (loc != null && _mapController != null) {
        _safeAnimateCamera(CameraUpdate.newLatLngZoom(loc, 17));
      }
      return;
    }
    // All clientes are marked — close the mini-card.
    setState(() => _miniCardClienteId = null);
  }

  /// Opt-in auto-complete after an explicit payment method tap. Returns true
  /// when the cliente was flipped to 'completed'. When the completed cliente is
  /// the one currently focused in Lista mode, advances the expanded card to the
  /// next pending cliente.
  ///
  /// Reads the toggle fresh from DB. Ruta sits in an IndexedStack and stays
  /// mounted while the sodero edits the setting in Configuración, so a cached
  /// field can lag the DB by one onDataChanged tick. The cost is one local
  /// SQLite read per payment tap.
  bool _isPagoUndoTap(int clienteId, String metodo) =>
      _clientePagos[clienteId]?.metodoPago == metodo &&
      !_provisionalPagoClientes.contains(clienteId);

  Future<bool> _maybeAutoCompleteOnPago(int clienteId) async {
    final enabled = await _db.getAutoListoOnPago();
    if (!enabled) return false;
    if (!mounted) return false;
    if (_getClientStatus(clienteId) == 'completed') return true;
    final shouldAdvanceList = _shouldAdvanceListAfterCompleting(clienteId);
    await _setClientStatus(clienteId, 'completed');
    if (shouldAdvanceList) {
      _advanceListAfterPaymentComplete(clienteId);
    }
    return true;
  }

  bool _shouldAdvanceListAfterCompleting(int clienteId) {
    if (_mapExpanded || _expandedClienteId == -1) return false;
    final expandedId = _expandedClienteId;
    if (expandedId != null) return expandedId == clienteId;
    return _activeClienteId == clienteId;
  }

  void _advanceListAfterPaymentComplete(int completedClienteId) {
    if (!mounted || _mapExpanded || _filteredClientes.isEmpty) return;

    final currentIdx = _filteredClientes.indexWhere(
      (c) => c.id == completedClienteId,
    );
    int? nextClienteId;
    if (currentIdx >= 0) {
      final count = _filteredClientes.length;
      for (var i = 1; i <= count; i++) {
        final candidate = _filteredClientes[(currentIdx + i) % count];
        if (_getClientStatus(candidate.id) == 'pending') {
          nextClienteId = candidate.id;
          break;
        }
      }
    } else {
      nextClienteId = _activeClienteId;
    }

    setState(() => _expandedClienteId = nextClienteId ?? -1);
    if (nextClienteId != null) {
      _ensureListCardVisible(nextClienteId);
    }
  }

  /// Auto-Listo desde el SHEET de un cliente: tras marcarlo listo y cerrar
  /// su panel, abrir el del siguiente pendiente para seguir de largo sin
  /// taps extra. (En la lista inline el "panel" es la card expandida y ya
  /// la mueve _advanceListAfterPaymentComplete.) Se programa post-frame
  /// para que el pop del sheet actual termine antes de abrir el próximo.
  void _openNextPendingPanelAfter(int completedClienteId) {
    if (!mounted || _mapExpanded || _filteredClientes.isEmpty) return;
    final currentIdx = _filteredClientes.indexWhere(
      (c) => c.id == completedClienteId,
    );
    if (currentIdx < 0) return;
    final count = _filteredClientes.length;
    for (var i = 1; i <= count; i++) {
      final idx = (currentIdx + i) % count;
      final candidate = _filteredClientes[idx];
      if (_getClientStatus(candidate.id) == 'pending') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _mapExpanded) return;
          _showClientDetail(candidate, idx);
        });
        return;
      }
    }
  }

  void _ensureListCardVisible(int clienteId, {int retriesRemaining = 2}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _listCardKeys[clienteId]?.currentContext;
      if (ctx == null && retriesRemaining > 0) {
        _ensureListCardVisible(
          clienteId,
          retriesRemaining: retriesRemaining - 1,
        );
        return;
      }
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: Duration(milliseconds: 260),
        alignment: 0.18,
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _clearDeferredStatusForActivity(int clienteId) async {
    if (_getClientStatus(clienteId) != 'deferred') {
      return;
    }
    if (mounted) {
      setState(() {
        _clienteStatus[clienteId] = 'pending';
        // Out-of-order edits — see _setClientStatus for rationale.
      });
    } else {
      _clienteStatus[clienteId] = 'pending';
      // Out-of-order edits — see _setClientStatus for rationale.
    }
    _emitStats();
    _buildClientMarkers();
    await _persistClientStatuses();
  }

  /// True when today's in-memory entregas for this cliente carry any
  /// `entregado` or `devuelto` quantity.
  bool _hasEntregaActivity(int clienteId) {
    final entregas = _clienteEntregas[clienteId];
    if (entregas == null || entregas.isEmpty) {
      return false;
    }
    for (final e in entregas.values) {
      if (e.entregado > 0 || e.devuelto > 0) return true;
    }
    return false;
  }

  bool _saltarWouldClearActivity(int clienteId) {
    return _hasEntregaActivity(clienteId) || _clientePagos[clienteId] != null;
  }

  Future<bool> _confirmSaltarIfActivity(
    int clienteId, {
    BuildContext? dialogContext,
  }) async {
    if (!_saltarWouldClearActivity(clienteId)) return true;
    final ctx = dialogContext ?? context;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Saltar cliente?',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Este cliente ya tiene venta o pago cargado hoy. Si lo saltás, se borra esa actividad del día.',
          style: TextStyle(color: tokens.textSub, height: 1.3),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Saltar y borrar',
              style: TextStyle(color: tokens.danger),
            ),
          ),
        ],
      ),
    );
    return mounted && confirmed == true;
  }

  /// Save the full client status map to the DB so deferred/pending states
  /// survive an app kill during an active recorrido.
  Future<void> _persistClientStatuses() async {
    if (widget.onStatsChanged == null ||
        widget.repartoId == null ||
        widget.selectedDay == null) {
      return; // only during active recorrido
    }
    final json = jsonEncode(
      _clienteStatus.map((k, v) => MapEntry(k.toString(), v)),
    );
    await _db.saveRecorridoClientStatuses(
      widget.repartoId!,
      widget.selectedDay!,
      json,
    );
  }

  /// Persist a status marker as a special pago entry so historial can show
  /// whether a client was absent or skipped (no compró).
  /// "Saltado" (deferred) does NOT create any historial entry — just skip entirely.
  Future<void> _persistStatusMarker(
    int clienteId,
    String newStatus,
    String oldStatus,
  ) async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    if (widget.repartoId == null) return;
    _localWriteCount++;
    try {
      final semana = _currentSemana;
      final day = _currentDay;
      final existingPago = _clientePagos[clienteId];
      // Status marker metodoPago values
      const markerMethods = {'no_compro', 'ausente', 'saltado'};
      final isExistingMarker =
          existingPago != null &&
          markerMethods.contains(existingPago.metodoPago);
      final hasRealPago =
          existingPago != null &&
          !markerMethods.contains(existingPago.metodoPago);

      if (newStatus == 'skipped' && !hasRealPago) {
        // Issue 1: "No compró" — customer didn't buy. Drop any draft qty
        // (they were never persisted) and write only the status marker.
        _clienteEntregas.remove(clienteId);
        _draftClienteIds.remove(clienteId);
        _committedToday.add(clienteId);
        await _db.setPago(
          clienteId,
          widget.repartoId!,
          semana,
          day,
          'no_compro',
          0,
        );
        await _refreshClienteCuentaCorriente(clienteId);
        await _refreshClienteDayState(clienteId, semana, day);
      } else if (newStatus == 'absent' && !hasRealPago) {
        // Issue 1: "Ausente" — customer wasn't there. Same as skipped.
        _clienteEntregas.remove(clienteId);
        _draftClienteIds.remove(clienteId);
        _committedToday.add(clienteId);
        await _db.setPago(
          clienteId,
          widget.repartoId!,
          semana,
          day,
          'ausente',
          0,
        );
        await _refreshClienteCuentaCorriente(clienteId);
        await _refreshClienteDayState(clienteId, semana, day);
      } else if (newStatus == 'deferred') {
        // Saltado = skip entirely, no DB entry. Remove any existing marker/pago.
        final uid = AuthService.currentUser?.id;
        if (isExistingMarker || hasRealPago) {
          await _db.deletePago(
            clienteId,
            widget.repartoId!,
            semana,
            day,
            userId: uid,
          );
        }
        // Also clear any entregas for today so nothing persists
        await _db.deleteEntregasForDay(
          clienteId,
          widget.repartoId!,
          semana,
          day,
          userId: uid,
        );
        // Issue 1: drop in-memory drafts too — Saltado means the cliente is
        // skipped for the day, no historial entry.
        _clienteEntregas.remove(clienteId);
        _draftClienteIds.remove(clienteId);
        _committedToday.remove(clienteId);
        await _refreshClienteCuentaCorriente(clienteId);
        await _refreshClienteDayState(clienteId, semana, day);
      } else if (newStatus == 'pending' && (isExistingMarker || hasRealPago)) {
        // Undoing a completed/marker status: clear pago AND entregas so the
        // next reload doesn't re-mark from leftover rows. Tombstones ensure
        // the cloud doesn't resurrect them on next pull.
        final uid = AuthService.currentUser?.id;
        await _db.deletePago(
          clienteId,
          widget.repartoId!,
          semana,
          day,
          userId: uid,
        );
        await _db.deleteEntregasForDay(
          clienteId,
          widget.repartoId!,
          semana,
          day,
          userId: uid,
        );
        // Issue 1: cliente reverts to uncommitted state. Drop drafts and
        // committed-today flag so qty edits become drafts again.
        _clienteEntregas.remove(clienteId);
        _draftClienteIds.remove(clienteId);
        _committedToday.remove(clienteId);
        await _refreshClienteCuentaCorriente(clienteId);
        await _refreshClienteDayState(clienteId, semana, day);
      }
    } finally {
      _localWriteCount--;
    }
  }

  /// Emit live stats to parent (HomeScreen) for the 4 stat boxes.
  void _emitStats() {
    if (widget.onStatsChanged == null) return;
    int visited = 0;
    int total = _clientes.length;
    int productsBought = 0;
    double recaudado = 0;
    double deudaTotal = 0;
    bool hasDeferredWithPayment = false;

    for (final c in _clientes) {
      final status = _getClientStatus(c.id);
      if (status == 'completed' || status == 'skipped' || status == 'absent') {
        visited++;
        // Count recaudado from finalized clients (any payment including status markers with monto)
        final pago = _clientePagos[c.id];
        if (pago != null && pago.metodoPago != 'no_pago' && pago.monto > 0) {
          recaudado += pago.monto;
        }
      }
      if (status == 'completed') {
        final entregas = _clienteEntregas[c.id] ?? {};
        for (final e in entregas.values) {
          productsBought += e.entregado;
        }
      }
      // Check if any deferred client has a real payment registered
      if (status == 'deferred') {
        final pago = _clientePagos[c.id];
        if (pago != null &&
            !{'no_compro', 'ausente', 'saltado'}.contains(pago.metodoPago)) {
          hasDeferredWithPayment = true;
        }
      }
      // Deuda de hoy: clients marked completed/skipped/absent who didn't pay or underpaid
      if (status == 'completed' || status == 'skipped' || status == 'absent') {
        final entregas = _clienteEntregas[c.id] ?? {};
        double totalOwed = 0;
        for (final e in entregas.values) {
          if (e.entregado > 0) {
            final clientSelections = _clientePrecioSelections[c.id];
            // P2.1: snapshot-first — historical price is the truth.
            final price = e.precioUnitario > 0
                ? e.precioUnitario
                : _getEffectivePrice(e.productoId, clientSelections);
            totalOwed += e.entregado * price;
          }
        }
        final pago = _clientePagos[c.id];
        final paid = (pago != null && pago.metodoPago != 'no_pago')
            ? pago.monto
            : 0.0;
        if (totalOwed > paid) {
          deudaTotal += totalOwed - paid;
        }
      }
    }

    widget.onStatsChanged!(
      visited,
      total,
      productsBought,
      recaudado,
      deudaTotal,
      hasDeferredWithPayment,
    );
  }

  /// Geocode client addresses and build map markers.
  Future<void> _geocodeClients() async {
    if (_geocodingRunning) return;
    _geocodingRunning = true;
    try {
      for (final c in _clientes) {
        final addressKey = _geocodeAddressKey(c.direccion);
        if (addressKey.isEmpty) {
          _geocodedLocations.remove(c.id);
          _geocodedAddressKeys.remove(c.id);
          continue;
        }
        if (_geocodedLocations.containsKey(c.id) &&
            _geocodedAddressKeys[c.id] == addressKey) {
          continue;
        }
        _geocodedLocations.remove(c.id);
        _geocodedAddressKeys.remove(c.id);
        try {
          final locations = await geo.locationFromAddress(c.direccion);
          if (locations.isNotEmpty) {
            final lat = locations.first.latitude;
            final lng = locations.first.longitude;
            if (!_isWithinArgentinaBounds(lat, lng)) continue;
            final latLng = LatLng(lat, lng);
            _geocodedLocations[c.id] = latLng;
            _geocodedAddressKeys[c.id] = addressKey;
            // Persist so the next Ruta open is instant. Fire-and-forget
            // intentionally — geocoding pass shouldn't block on the DB
            // write, and a failed write just means we'll re-geocode next
            // time (same behavior as today).
            unawaited(
              _db.setClienteGeocode(
                c.id,
                latLng.latitude,
                latLng.longitude,
                c.direccion,
              ),
            );
          }
        } catch (_) {
          // Address couldn't be geocoded — skip
        }
      }
      _buildClientMarkers();
    } finally {
      _geocodingRunning = false;
      if (mounted) setState(() {});
    }
  }

  /// Build marker set from geocoded locations, handling overlaps.
  void _buildClientMarkers() {
    final markers = <Marker>{};
    final placed = <LatLng>[];

    for (final c in _clientes) {
      if (!c.showOnMap) continue;
      final loc = _geocodedLocations[c.id];
      if (loc == null) continue;

      // Count how many already-placed markers are within ~30m
      int overlapCount = 0;
      for (final existing in placed) {
        final dlat = (existing.latitude - loc.latitude).abs();
        final dlng = (existing.longitude - loc.longitude).abs();
        if (dlat < 0.0003 && dlng < 0.0003) overlapCount++;
      }

      var finalLoc = loc;
      if (overlapCount > 0) {
        final angle = overlapCount * (2 * pi / 6); // distribute in hexagon
        finalLoc = LatLng(
          loc.latitude + 0.00015 * cos(angle),
          loc.longitude + 0.00015 * sin(angle),
        );
      }
      placed.add(finalLoc);

      final status = _getClientStatus(c.id);
      final hue = status == 'completed'
          ? BitmapDescriptor.hueGreen
          : status == 'skipped'
          ? BitmapDescriptor.hueRed
          : status == 'absent'
          ? BitmapDescriptor.hueOrange
          : status == 'deferred'
          ? BitmapDescriptor.hueViolet
          : BitmapDescriptor.hueAzure;

      final idx = _clientes.indexOf(c);
      markers.add(
        Marker(
          markerId: MarkerId('client_${c.id}'),
          position: finalLoc,
          infoWindow: InfoWindow(title: c.nombre, snippet: c.direccion),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () {
            if (_mapExpanded) {
              setState(() => _miniCardClienteId = c.id);
              if (_mapController != null) {
                _safeAnimateCamera(CameraUpdate.newLatLngZoom(finalLoc, 17));
              }
            } else {
              _showClientDetail(c, idx);
            }
          },
        ),
      );
    }

    if (mounted) {
      setState(() => _clientMarkers = markers);
    }
    _buildRoutePolyline();
    _focusMapOnFallbackIfNeeded();
  }

  void _buildRoutePolyline() {
    final points = <LatLng>[];
    for (final c in _clientes) {
      if (!c.showOnMap) continue;
      final loc = _geocodedLocations[c.id];
      if (loc != null) points.add(loc);
    }
    if (points.length < 2) {
      if (mounted) setState(() => _routePolylines = {});
      return;
    }
    if (mounted) {
      setState(() {
        _routePolylines = {
          Polyline(
            polylineId: PolylineId('route'),
            points: points,
            color: tokens.primaryBlue.withValues(alpha: 0.4),
            width: 2,
            patterns: [PatternItem.dash(10), PatternItem.gap(6)],
          ),
        };
      });
    }
  }

  /// The first client in the filtered list that is still pending (not deferred/completed/skipped)
  int? get _activeClienteId {
    for (final c in _filteredClientes) {
      final s = _getClientStatus(c.id);
      if (s == 'pending') return c.id;
    }
    return null;
  }

  Color _statusCardColor(String status) {
    return tokens.card;
  }

  Color _statusBorderColor(String status) {
    return tokens.cardBorder;
  }

  Border _clienteCardBorder({
    required String status,
    required bool isMovedHighlight,
    required bool isMarked,
  }) {
    if (isMovedHighlight) {
      return Border.all(color: tokens.primaryBlue, width: 2);
    }
    if (_markingMode && isMarked) {
      return Border.all(color: tokens.warn, width: 2);
    }
    if (_markingMode) {
      return Border.all(color: tokens.warn.withValues(alpha: 0.35));
    }
    return Border.all(color: _statusBorderColor(status));
  }

  /// Returns the background color for the number circle based on client status.
  Color? _statusCircleColor(String status) {
    switch (status) {
      case 'completed':
        return tokens.success;
      case 'skipped':
        return tokens.danger;
      case 'absent':
        return tokens.warn;
      case 'deferred':
        return tokens.textMuted;
      default:
        return null;
    }
  }

  String _saldoLabel(double cuentaCorriente) {
    if (isMoneyEffectivelyZero(cuentaCorriente)) return '\$0';
    final sign = isMoneyNegative(cuentaCorriente) ? '-' : '+';
    return '$sign\$${cuentaCorriente.abs().toStringAsFixed(0)}';
  }

  Widget _buildStatusBadge(String status, int number, {bool editMode = false}) {
    final isPending = status == 'pending';
    final accent = _statusCircleColor(status);

    final Color bg;
    final Color fg;
    if (isPending) {
      bg = tokens.primaryBlue.withValues(alpha: 0.2);
      fg = editMode ? tokens.primaryBlue : tokens.primaryBlue;
    } else if (accent != null) {
      bg = accent;
      fg = tokens.text;
    } else {
      bg = tokens.text.withValues(alpha: 0.10);
      fg = tokens.textMuted;
    }

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: isPending
            ? null
            : Border.all(color: tokens.cardBorder.withValues(alpha: 0.4)),
      ),
      // Always show the route order number — the bg color alone
      // communicates the status (green / red / orange / muted / tinted).
      // FittedBox.scaleDown lets 3-digit (100+) numbers shrink to fit
      // the 32-wide badge instead of clipping. 1-2 digits render at
      // full natural size.
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$number',
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // --- Entrega & Pago updates ---

  /// Returns true if a sodero is allowed to write entregas/pagos right now.
  /// When the reparto hasn't been started (HomeScreen only passes
  /// onStatsChanged once _repartoConfirmed flips true), we ask once whether
  /// they really want to anotar without clocking in. After they confirm,
  /// the rest of the session is silent until the toggle flips again.
  Future<bool> _confirmAnotarSinReparto() async {
    if (widget.onStatsChanged != null) return true;
    if (_noRepartoWarningAcked) return true;
    if (!mounted) return false;
    final inFlight = _noRepartoWarningInFlight;
    if (inFlight != null) return inFlight;

    final confirmation = showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Anotar sin empezar reparto?',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Todavía no empezaste el reparto. ¿Querés anotar igualmente?',
          style: TextStyle(color: tokens.textSub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Anotar igual',
              style: TextStyle(color: tokens.primaryBlue),
            ),
          ),
        ],
      ),
    );
    _noRepartoWarningInFlight = confirmation
        .then((result) {
          if (result == true) {
            _noRepartoWarningAcked = true;
            return true;
          }
          return false;
        })
        .whenComplete(() {
          _noRepartoWarningInFlight = null;
        });
    return _noRepartoWarningInFlight!;
  }

  Future<void> _refreshClienteDayState(
    int clienteId,
    String semana,
    int day,
  ) async {
    if (widget.repartoId == null) return;
    final entregas = await _db.getEntregasForClient(
      clienteId,
      widget.repartoId!,
      semana,
      day,
    );
    final pago = await _db.getPago(clienteId, widget.repartoId!, semana, day);
    if (!mounted) return;
    setState(() {
      if (entregas.isEmpty) {
        _clienteEntregas.remove(clienteId);
      } else {
        _clienteEntregas[clienteId] = {
          for (final e in entregas) e.productoId: e,
        };
      }
      if (pago == null) {
        _clientePagos.remove(clienteId);
      } else {
        _clientePagos[clienteId] = pago;
      }
      final hasPago = pago != null;
      final hasNonZeroEntrega = entregas.any((e) => e.entregado > 0);
      if (hasPago || hasNonZeroEntrega) {
        _committedToday.add(clienteId);
      } else {
        _committedToday.remove(clienteId);
      }
    });
    _emitStats();
  }

  Future<void> _syncInlineMontoControllerFromPago(int clienteId) async {
    final freshPago = _clientePagos[clienteId];
    final controller = _inlineMontoControllers[clienteId];
    final focusNode = _inlineMontoFocusNodes[clienteId];
    if (controller != null && (focusNode == null || !focusNode.hasFocus)) {
      final newText = freshPago != null && freshPago.monto > 0
          ? freshPago.monto.toStringAsFixed(0)
          : '';
      if (controller.text != newText) {
        controller.text = newText;
      }
    }
  }

  void _rememberEditingPagoMethod(int clienteId, String? metodoPago) {
    if (isRealPaymentMethod(metodoPago)) {
      _editingPagoMethods[clienteId] = metodoPago!;
    }
  }

  String? _rememberedEditingPagoMethod(int clienteId) {
    final current = _clientePagos[clienteId]?.metodoPago;
    if (isRealPaymentMethod(current)) return current;
    if (current != null) return null;
    return _editingPagoMethods[clienteId];
  }

  FocusNode _inlineMontoFocusNodeFor(int clienteId) {
    final focusNode = _inlineMontoFocusNodes.putIfAbsent(
      clienteId,
      () => FocusNode(),
    );
    if (_inlineMontoFocusListenerIds.add(clienteId)) {
      focusNode.addListener(() {
        if (mounted && !focusNode.hasFocus) {
          unawaited(_commitInlineMontoEdit(clienteId));
        }
      });
    }
    return focusNode;
  }

  Future<bool> _commitInlineMontoEdit(int clienteId) async {
    if (!_manuallyEditedMonto.contains(clienteId)) return true;
    final controller = _inlineMontoControllers[clienteId];
    if (controller == null) {
      _manuallyEditedMonto.remove(clienteId);
      return true;
    }

    final action = resolvePaymentEditAction(
      rawMonto: controller.text,
      currentMetodoPago: _clientePagos[clienteId]?.metodoPago,
      rememberedMetodoPago: _rememberedEditingPagoMethod(clienteId),
      commit: true,
    );

    switch (action.kind) {
      case PaymentEditActionKind.save:
        final saved = await _setPago(
          clienteId,
          action.metodoPago!,
          action.monto,
        );
        return saved;
      case PaymentEditActionKind.remove:
        await _removePago(clienteId);
        return true;
      case PaymentEditActionKind.none:
        _manuallyEditedMonto.remove(clienteId);
        return true;
      case PaymentEditActionKind.needsMethod:
        return false;
    }
  }

  Future<void> _updateEntrega(
    int clienteId,
    int productoId, {
    int? entregado,
    int? devuelto,
  }) async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    if (widget.repartoId == null) return;
    final recordsTutorialEntrega = (entregado ?? 0) > 0;
    // Only gate when the user is actually *increasing* entrega/devuelto into
    // positive territory — zeroing out a stale value shouldn't prompt the
    // dialog. The existing-entrega lookup mirrors what the write path does
    // a few lines down.
    final existingEntrega = _clienteEntregas[clienteId]?[productoId];
    final willHaveEntregado = entregado ?? existingEntrega?.entregado ?? 0;
    final willHaveDevuelto = devuelto ?? existingEntrega?.devuelto ?? 0;
    final isPositiveWrite = willHaveEntregado > 0 || willHaveDevuelto > 0;
    // Block entregas on products without a configured sale price.
    // product.precio (factory cost) is intentionally ignored — only
    // producto_precios (sale price types) count as "configured".
    if (entregado != null && entregado > 0) {
      final overridePrice = _overridePrices[clienteId]?[productoId];
      final hasManualPrice = overridePrice != null && overridePrice > 0;
      final hasSalePrice = _productPrices[productoId]?.isNotEmpty ?? false;
      if (!hasSalePrice && !hasManualPrice) {
        final productName = _productMap[productoId]?.nombre ?? 'este producto';
        if (mounted) {
          final messenger =
              _sheetMessengerKey.currentState ?? ScaffoldMessenger.of(context);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Configurá un precio para "$productName" antes de venderlo',
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
        }
        return;
      }
    }
    if (isPositiveWrite) {
      final ok = await _confirmAnotarSinReparto();
      if (!ok) return;
    }
    _localWriteCount++;
    try {
      final semana = _currentSemana;
      final day = _currentDay;
      final existing = _clienteEntregas[clienteId]?[productoId];
      final newEntregado = entregado ?? existing?.entregado ?? 0;
      final newDevuelto = devuelto ?? existing?.devuelto ?? 0;
      final hasProductActivity = newEntregado > 0 || newDevuelto > 0;
      if (hasProductActivity) {
        await _clearDeferredStatusForActivity(clienteId);
      }
      // Issue 2: read effective price from DB at the moment of write — not from
      // _productPrices in-memory cache. The cache is populated at _loadData
      // time, so a price edit in another screen (Carga, producto edit) leaves
      // it stale until the next reload, and a +1 tap during that race window
      // stamps the entrega with the OLD price (the $5600→$6000 bug).
      // The override map wins over the configured-price-type lookup so a
      // one-shot manual price entered via the precio chip travels onto
      // every new tap of +/- for this cliente/product on this day.
      final overridePrice = _overridePrices[clienteId]?[productoId];
      final hasOverride = overridePrice != null && overridePrice > 0;
      final precio = hasOverride
          ? overridePrice
          : await _db.getEffectivePrice(clienteId, productoId);

      // Issue 1: deferred-commit fork.
      // - Cliente NOT yet committed today: just mutate _clienteEntregas in
      //   memory and mark them as having drafts. NO DB write. NO recalc.
      //   Cuenta corriente / Deudor pill stays at the previous (correct)
      //   stored value until the user picks a payment / status chip.
      // - Cliente IS committed today: write through (UPSERT updates the
      //   existing day's entrega row, recalc atomic in setEntrega).
      if (!_committedToday.contains(clienteId)) {
        if (mounted) {
          setState(() {
            final dayMap = _clienteEntregas.putIfAbsent(clienteId, () => {});
            if (hasProductActivity) {
              dayMap[productoId] = Entrega(
                id: existing?.id ?? -1, // -1 marker for un-persisted draft row
                clienteId: clienteId,
                repartoId: widget.repartoId!,
                productoId: productoId,
                semana: semana,
                diaSemana: day,
                entregado: newEntregado,
                devuelto: newDevuelto,
                precioUnitario: precio,
              );
            } else {
              dayMap.remove(productoId);
              if (dayMap.isEmpty) {
                _clienteEntregas.remove(clienteId);
              }
            }
            if (_hasEntregaActivity(clienteId)) {
              _draftClienteIds.add(clienteId);
            } else {
              _draftClienteIds.remove(clienteId);
            }
          });
          _manuallyEditedMonto.remove(clienteId);
          _refreshInlineMonto(clienteId);
          _emitStats();
        }
        if (recordsTutorialEntrega) {
          TutorialController.instance.onEntregaRecorded();
        }
        return;
      }

      // Committed path: existing flow + cliente CC refresh so the Deudor pill
      // updates from the freshly-computed clientes.cuenta_corriente row.
      if (hasOverride) {
        await _db.setEntregaWithPrecioUnitarioOverride(
          clienteId,
          widget.repartoId!,
          productoId,
          semana,
          day,
          newEntregado,
          newDevuelto,
          precio,
        );
      } else {
        await _db.setEntrega(
          clienteId,
          widget.repartoId!,
          productoId,
          semana,
          day,
          newEntregado,
          newDevuelto,
          precioUnitario: precio,
        );
      }
      final entregas = await _db.getEntregasForClient(
        clienteId,
        widget.repartoId!,
        semana,
        day,
      );
      if (mounted) {
        setState(() {
          _clienteEntregas[clienteId] = {
            for (final e in entregas) e.productoId: e,
          };
        });
        _manuallyEditedMonto.remove(clienteId);
        _refreshInlineMonto(clienteId);
        _emitStats();
        _checkStockLowForProduct(productoId, semana, day);
      }
      // Issue 1: targeted single-cliente refresh of cuenta_corriente. The
      // recalc already ran atomically inside setEntrega; this just patches
      // the screen's _clientes / _filteredClientes copy so the Deudor pill
      // reflects the new value within one frame. Do NOT bulk refresh.
      await _refreshClienteCuentaCorriente(clienteId);
      if (recordsTutorialEntrega) {
        TutorialController.instance.onEntregaRecorded();
      }
    } finally {
      _localWriteCount--;
    }
  }

  Future<void> _checkStockLowForProduct(
    int productoId,
    String semana,
    int day,
  ) async {
    if (widget.repartoId == null) return;
    final masterEnabled = await _db.getStockNotifMasterEnabled();
    if (!masterEnabled) return;
    final setting = await _db.getStockNotifSetting(productoId);
    if (setting == null || !setting.enabled) return;

    final carga = _cargaForDay[productoId] ?? 0;
    if (carga == 0) return; // no stock loaded

    final totalSold = await _db.getTotalEntregadoForProduct(
      widget.repartoId!,
      productoId,
      semana,
      day,
    );
    final remaining = carga - totalSold;

    if (remaining <= setting.threshold && remaining >= 0) {
      // Only fire if not already notified today
      if (await _db.hasStockLowNotifToday(productoId)) return;
      final product = _productMap[productoId];
      final productName = product?.nombre ?? 'Producto';
      await _db.addNotification(
        type: 'stock_low',
        title: 'Carga baja: $productName',
        body: 'Quedan $remaining unidades de $productName (cargaste $carga).',
        clienteId: productoId, // reuse clienteId field to store productoId
      );
    }
  }

  /// Recalculate and update the inline monto controller (and saved pago) for a client.
  /// Skips if the user has manually edited the monto.
  void _refreshInlineMonto(int clienteId) {
    final pago = _clientePagos[clienteId];
    // Don't override if no_pago is selected (should stay 0)
    if (pago != null && pago.metodoPago == 'no_pago') return;
    // Don't override if the user manually edited the amount
    if (_manuallyEditedMonto.contains(clienteId)) return;
    final entregasForClient = _clienteEntregas[clienteId] ?? {};
    final totalOwed = _calcTotalOwed(entregasForClient, clienteId: clienteId);
    final montoStr = totalOwed > 0 ? totalOwed.toStringAsFixed(0) : '';
    // Update text controller if it exists
    final controller = _inlineMontoControllers[clienteId];
    if (controller != null) {
      controller.text = montoStr;
    }
    // If a payment method is already selected, sync the saved pago to the
    // recalculated total. When totalOwed drops to 0 (e.g. the sodero reduced
    // every qty back to zero) there's nothing being paid, so drop the pago
    // entirely instead of leaving a $0 efectivo/transferencia row behind —
    // the chip should deselect to match. `no_pago` is excluded above and
    // manually-edited monto skips even earlier, so this only touches the
    // qty-driven auto-refresh.
    if (pago != null && widget.repartoId != null) {
      if (totalOwed <= 0) {
        _removePago(clienteId);
        return;
      }
      final semana = _currentSemana;
      final day = _currentDay;
      _localWriteCount++;
      _runQueuedPagoOp<void>(clienteId, () async {
        await _db.setPago(
          clienteId,
          widget.repartoId!,
          semana,
          day,
          pago.metodoPago,
          totalOwed,
        );
        await _recalcCuentaCorriente(clienteId);
        await _refreshClienteDayState(clienteId, semana, day);
      }).whenComplete(() => _localWriteCount--);
    }
  }

  /// Writes a pago for today. Returns `true` on success, `false` if the
  /// sodero cancelled the "anotar sin empezar reparto" gate (so auto-listo
  /// chains can skip themselves rather than flipping a client to completed
  /// when no pago was actually recorded).
  Future<bool> _setPago(int clienteId, String metodoPago, double monto) async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return false;
    final saved = await _runQueuedPagoOp(
      clienteId,
      () => _setPagoInternal(clienteId, metodoPago, monto),
    );
    if (saved) TutorialController.instance.onPagoRecorded();
    return saved;
  }

  Future<bool> _setPagoInternal(
    int clienteId,
    String metodoPago,
    double monto,
  ) async {
    if (widget.repartoId == null) return false;
    final ok = await _confirmAnotarSinReparto();
    if (!ok) return false;
    _localWriteCount++;
    try {
      final semana = _currentSemana;
      final day = _currentDay;
      await _clearDeferredStatusForActivity(clienteId);

      // Issue 1: if this cliente has pending draft entregas, write them to DB
      // BEFORE the pago. Each setEntrega auto-recalcs cuenta_corriente in its
      // own transaction (post-v46 atomic UPSERT contract). After all
      // drafts + the pago are written, the stored cuenta_corriente reflects
      // every change. Move the cliente from drafts to _committedToday so
      // future qty edits write through directly.
      if (_draftClienteIds.contains(clienteId)) {
        final draftEntregas = _clienteEntregas[clienteId] ?? <int, Entrega>{};
        for (final entry in draftEntregas.entries) {
          final e = entry.value;
          if (e.entregado > 0 || e.devuelto > 0) {
            await _db.setEntrega(
              clienteId,
              widget.repartoId!,
              entry.key,
              semana,
              day,
              e.entregado,
              e.devuelto,
              precioUnitario: e.precioUnitario,
            );
          }
        }
        _draftClienteIds.remove(clienteId);
        _committedToday.add(clienteId);
      }

      await _db.setPago(
        clienteId,
        widget.repartoId!,
        semana,
        day,
        metodoPago,
        monto,
      );
      _committedToday.add(clienteId);
      // Todo pago guardado nace "provisional". Los taps explícitos de método lo
      // limpian justo después (lo marcan finalizado); los guardados por tipeo /
      // blur lo dejan provisional, así un tap posterior del mismo método
      // finaliza en vez de borrar. Ver _isPagoUndoTap.
      _provisionalPagoClientes.add(clienteId);
      // Cuenta corriente was atomically recomputed inside setPago's
      // transaction. Refresh the screen's copy so the Deudor pill updates.
      await _refreshClienteCuentaCorriente(clienteId);
      await _refreshClienteDayState(clienteId, semana, day);
      // Sync the inline monto controller to match the freshly-stored pago.
      // The inline preview and the detail panel show the SAME pago — they
      // should always agree. Without this, after the panel commits and
      // closes, the inline keeps showing the old value (the controller text
      // doesn't update from the DB). Skip when the inline field is
      // focused so we don't fight a user who's actively typing.
      await _syncInlineMontoControllerFromPago(clienteId);
      if (isRealPaymentMethod(metodoPago)) {
        _rememberEditingPagoMethod(clienteId, metodoPago);
      } else {
        _editingPagoMethods.remove(clienteId);
      }
      _manuallyEditedMonto.remove(clienteId);
    } finally {
      _localWriteCount--;
    }
    return true;
  }

  Future<void> _removePago(int clienteId) {
    return _runQueuedPagoOp(clienteId, () => _removePagoInternal(clienteId));
  }

  Future<void> _removePagoInternal(int clienteId) async {
    if (widget.repartoId == null) return;
    _localWriteCount++;
    try {
      final semana = _currentSemana;
      final day = _currentDay;
      await _db.deletePago(
        clienteId,
        widget.repartoId!,
        semana,
        day,
        userId: AuthService.currentUser?.id,
      );
      await _recalcCuentaCorriente(clienteId);
      _manuallyEditedMonto.remove(clienteId);
      _editingPagoMethods.remove(clienteId);
      _provisionalPagoClientes.remove(clienteId);
      await _refreshClienteDayState(clienteId, semana, day);
      // Same sync as _setPago — pago is now gone, so the inline field
      // should clear (or fall back to its default text on next refresh).
      final controller = _inlineMontoControllers[clienteId];
      final focusNode = _inlineMontoFocusNodes[clienteId];
      if (controller != null && (focusNode == null || !focusNode.hasFocus)) {
        if (controller.text.isNotEmpty) controller.text = '';
      }
    } finally {
      _localWriteCount--;
    }
  }

  /// Show a Mercado Pago QR code for collecting payment from a client.
  void _showMpQrDialog(int clienteId, double monto, String clienteName) {
    // Mercado Pago crea una preferencia de pago REAL — bloqueado en demo.
    if (blockDemoAction(context)) return;
    if (_mpAccessToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Configurá tu Access Token de Mercado Pago en Mi Perfil',
          ),
          backgroundColor: tokens.warn,
        ),
      );
      return;
    }
    if (monto <= 0) {
      _showMontoWarning();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MpQrDialog(
        accessToken: _mpAccessToken,
        amount: monto,
        clienteName: clienteName,
        onPaymentConfirmed: () async {
          // Secuenciado (antes era fire-and-forget): el auto-Listo tiene
          // que completar ANTES del snackbar para que el estado/avance no
          // corra contra el cierre del diálogo QR.
          final ok = await _setPago(clienteId, 'transferencia', monto);
          if (ok) {
            _provisionalPagoClientes.remove(clienteId);
            await _maybeAutoCompleteOnPago(clienteId);
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pago de \$${monto.toStringAsFixed(0)} recibido'),
              backgroundColor: tokens.success,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  /// Recalculate cuenta corriente for a client.
  /// CC = total amount paid across all deliveries (efectivo + transferencia).
  /// Shows how much the client has paid in total.
  /// Issue 1: legacy screen-side recalc, kept as a thin shim for callers
  /// that still invoke it. cuenta_corriente is now recomputed atomically
  /// inside setEntrega / setPago in the DB layer (post-v46), and the old
  /// screen-side body had two bugs: (1) stale in-memory _productPrices
  /// cache (the $5600→$6000 bug), and (2) only excluded 'no_pago' from
  /// paid totals — missed 'no_compro'/'ausente'/'saltado'. So we just
  /// refresh the in-memory cliente row from the freshly-computed DB
  /// value. Callers can be migrated to call _refreshClienteCuentaCorriente
  /// directly over time.
  Future<void> _recalcCuentaCorriente(int clienteId) async {
    await _refreshClienteCuentaCorriente(clienteId);
  }

  // --- Navigation ---

  Future<void> _openMapsWithAddress(String address) async {
    if (!mounted) return;
    showDemoUpgradeSnack(
      context,
      message: 'La navegacion externa no esta disponible en la demo.',
    );
  }

  void _navigateToClientOnMap(Cliente cliente, {bool popSheet = true}) {
    // Close the detail sheet first if called from a sheet
    if (popSheet) Navigator.of(context).pop();
    final loc = _geocodedLocations[cliente.id];
    if (loc != null) {
      // Null out old controller before expanding — the expanded map will set a new one
      _mapController = null;
      setState(() {
        _mapExpanded = true;
        _miniCardClienteId = cliente.id;
      });
      _geocodeClients();
      // Wait for the expanded map to build and set the new controller
      Future.delayed(Duration(milliseconds: 400), () {
        if (_mapController != null && mounted) {
          _safeAnimateCamera(CameraUpdate.newLatLngZoom(loc, 17));
        }
      });
    } else if (cliente.direccion.isNotEmpty) {
      // Geocode first, then show on map
      _geocodeAndShowOnMap(cliente);
    }
  }

  Future<void> _geocodeAndShowOnMap(Cliente cliente) async {
    await _openMapsWithAddress(cliente.direccion);
  }

  // ignore: unused_element
  Future<void> _openMapsAtCoordinates(LatLng point) async {
    await _openMapsWithAddress('${point.latitude}, ${point.longitude}');
  }

  // --- Client detail sheet (client.png) ---

  void _showClientDetail(Cliente cliente, int displayIndex) {
    // Tutorial: in the real app, opening the big profile from the "atendé el
    // ejemplo" step auto-advances into the hands-on sell step. In demo it
    // waits until the read-only sheet closes so users can look around first.
    TutorialController.instance.onClientDetailOpened();
    // Load history data asynchronously
    List<_HistoryEntry> historyEntries = [];
    int historyPage = 0;
    bool historyLoaded = false;
    double localCc = cliente.cuentaCorriente;
    Map<int, int> enLaCalle = {};
    bool panelMontoManuallyEdited = false;
    int activeTab = 0;
    bool sheetMounted = true;
    Timer? datosDebounce;
    bool datosListenersAdded = false;

    final pago0 = _clientePagos[cliente.id];
    final entregasForClient0 = _clienteEntregas[cliente.id] ?? {};
    final totalOwed0 = _calcTotalOwed(
      entregasForClient0,
      clienteId: cliente.id,
    );
    final panelMontoController = TextEditingController(
      text: pago0 != null && pago0.monto > 0
          ? pago0.monto.toStringAsFixed(0)
          : totalOwed0 > 0
          ? totalOwed0.toStringAsFixed(0)
          : '',
    );
    final datosNombreController = TextEditingController(text: cliente.nombre);
    final datosTelefonoController = TextEditingController(
      text: cliente.telefono,
    );
    final datosDireccionController = TextEditingController(
      text: cliente.direccion,
    );
    final datosNotasController = TextEditingController(text: cliente.notas);
    final panelMontoFocus = FocusNode();

    Future<void> saveDatos() async {
      if (kDemoMode) return;
      final nombre = datosNombreController.text.trim();
      if (nombre.isEmpty) return;
      await _db.updateCliente(
        cliente.id,
        nombre: nombre,
        telefono: datosTelefonoController.text.trim(),
        direccion: datosDireccionController.text.trim(),
        notas: datosNotasController.text.trim(),
      );
    }

    void scheduleDatosSave() {
      if (kDemoMode) return;
      datosDebounce?.cancel();
      datosDebounce = Timer(Duration(milliseconds: 500), saveDatos);
    }

    void Function(VoidCallback)? sheetSetState;

    Future<void> refreshCc() async {
      if (!sheetMounted) return;
      final allClientes = await _db.getClientesForReparto(widget.repartoId!);
      if (!sheetMounted) return;
      final updated = allClientes.where((c) => c.id == cliente.id).firstOrNull;
      if (updated != null) {
        localCc = updated.cuentaCorriente;
      }
      sheetSetState?.call(() {});
    }

    // Issue 4: commit on focus-loss + on panel dismiss. Without this, typing a
    // monto in the panel and closing without unfocusing first dropped the
    // value silently. Defaults to efectivo when no pago exists yet (or when
    // it's no_pago) so the user doesn't have to tap a chip first.
    Future<bool> commitPanelMonto() async {
      if (kDemoMode) return false;
      if (!panelMontoManuallyEdited) return true;
      final action = resolvePaymentEditAction(
        rawMonto: panelMontoController.text,
        currentMetodoPago: _clientePagos[cliente.id]?.metodoPago,
        rememberedMetodoPago: _rememberedEditingPagoMethod(cliente.id),
        commit: true,
        defaultPositiveToEfectivo: true,
      );
      var saved = true;
      switch (action.kind) {
        case PaymentEditActionKind.save:
          saved = await _setPago(cliente.id, action.metodoPago!, action.monto);
          break;
        case PaymentEditActionKind.remove:
          await _removePago(cliente.id);
          break;
        case PaymentEditActionKind.none:
          break;
        case PaymentEditActionKind.needsMethod:
          saved = false;
          break;
      }
      if (saved) {
        panelMontoManuallyEdited = false;
      }
      await refreshCc();
      return saved;
    }

    panelMontoFocus.addListener(() {
      if (!panelMontoFocus.hasFocus && panelMontoManuallyEdited) {
        unawaited(commitPanelMonto());
      }
    });

    Future<List<_HistoryEntry>> loadHistory() async {
      final allEntregas = await _db.getAllEntregasForClient(
        cliente.id,
        widget.repartoId!,
      );
      final allPagos = await _db.getAllPagosForClient(
        cliente.id,
        widget.repartoId!,
      );

      // Group entregas by (semana, diaSemana)
      final grouped = <String, List<Entrega>>{};
      for (final e in allEntregas) {
        final key = '${e.semana}|${e.diaSemana}';
        grouped.putIfAbsent(key, () => []).add(e);
      }

      // Build pago lookup
      final pagoLookup = <String, Pago>{};
      for (final p in allPagos) {
        pagoLookup['${p.semana}|${p.diaSemana}'] = p;
      }

      // Also include pago-only entries (status markers without entregas)
      for (final p in allPagos) {
        final key = '${p.semana}|${p.diaSemana}';
        grouped.putIfAbsent(key, () => []);
      }

      // Build entries sorted by date desc
      final entries = <_HistoryEntry>[];
      final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final key in sortedKeys) {
        final parts = key.split('|');
        final semana = parts[0];
        final dia = int.parse(parts[1]);
        final entregas = grouped[key]!;
        final pago = pagoLookup[key];

        // Build per-product delivery items
        final deliveries = <_DeliveryItem>[];
        for (final e in entregas) {
          final pName = _productMap[e.productoId]?.nombre ?? '?';
          if (e.entregado > 0 || e.devuelto > 0) {
            deliveries.add(
              _DeliveryItem(
                productoId: e.productoId,
                productName: _shortenProductName(pName),
                entregado: e.entregado,
                devuelto: e.devuelto,
                precioUnitario: e.precioUnitario,
              ),
            );
          }
        }

        final hasDelivery = entregas.any(
          (e) => e.entregado > 0 || e.devuelto > 0,
        );
        final dateLabel = _weekDayToDateStr(semana, dia);
        // Parse actual date for month grouping
        final actualDate = _weekDayToDate(semana, dia);

        // Calculate total owed using snapshotted prices (fall back to current if not stored)
        double dayTotal = 0;
        final clientSelections = _clientePrecioSelections[cliente.id];
        for (final e in entregas) {
          final precio = e.precioUnitario > 0
              ? e.precioUnitario
              : _getEffectivePrice(e.productoId, clientSelections);
          if (precio > 0) {
            dayTotal += precio * e.entregado;
          }
        }

        entries.add(
          _HistoryEntry(
            dateLabel: dateLabel,
            dayAbbr: _dayAbbr(dia),
            month: actualDate?.month ?? 1,
            year: actualDate?.year ?? DateTime.now().year,
            deliveries: deliveries,
            monto: pago?.monto ?? 0,
            totalOwed: dayTotal,
            metodoPago: pago?.metodoPago,
            noCompro:
                pago?.metodoPago == 'no_compro' ||
                (!hasDelivery && pago == null),
            ausente: pago?.metodoPago == 'ausente',
            saltado: pago?.metodoPago == 'saltado',
            semana: semana,
            diaSemana: dia,
          ),
        );
      }

      return entries;
    }

    showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetCtx) {
            return StatefulBuilder(
              builder: (sheetCtx, setSheetState) {
                sheetSetState = setSheetState;
                // Load history once
                if (!historyLoaded) {
                  historyLoaded = true;
                  // Recalculate CC and load history
                  _recalcCuentaCorriente(cliente.id)
                      .then((_) {
                        return _db.getClientesForReparto(widget.repartoId!);
                      })
                      .then((allClientes) {
                        if (!sheetMounted) return Future.value(<dynamic>[]);
                        final updated = allClientes
                            .where((c) => c.id == cliente.id)
                            .firstOrNull;
                        if (updated != null) {
                          localCc = updated.cuentaCorriente;
                        }
                        return Future.wait([
                          loadHistory(),
                          _db.getProductosEnLaCalle(
                            cliente.id,
                            widget.repartoId!,
                          ),
                        ]);
                      })
                      .then((results) {
                        if (!sheetMounted || results.isEmpty) return;
                        setSheetState(() {
                          historyEntries = results[0] as List<_HistoryEntry>;
                          enLaCalle = results[1] as Map<int, int>;
                        });
                      });
                }

                final pago = _clientePagos[cliente.id];
                final entregasForClient = _clienteEntregas[cliente.id] ?? {};
                final totalOwed = _calcTotalOwed(
                  entregasForClient,
                  clienteId: cliente.id,
                );

                // Update controller only if user hasn't manually edited
                if (!panelMontoManuallyEdited) {
                  final newText = pago != null && pago.monto > 0
                      ? pago.monto.toStringAsFixed(0)
                      : totalOwed > 0
                      ? totalOwed.toStringAsFixed(0)
                      : '';
                  if (panelMontoController.text != newText) {
                    panelMontoController.text = newText;
                  }
                }
                final montoController = panelMontoController;
                if (!kDemoMode && !datosListenersAdded) {
                  datosListenersAdded = true;
                  for (final ctrl in [
                    datosNombreController,
                    datosTelefonoController,
                    datosDireccionController,
                    datosNotasController,
                  ]) {
                    ctrl.addListener(scheduleDatosSave);
                  }
                }

                // Cuenta corriente from local tracking
                final cc = localCc;

                // Group history by month (year-month), sorted most recent first
                final monthGroups = <String, List<_HistoryEntry>>{};
                for (final e in historyEntries) {
                  final key = '${e.year}-${e.month.toString().padLeft(2, '0')}';
                  monthGroups.putIfAbsent(key, () => []).add(e);
                }
                final sortedMonths = monthGroups.keys.toList()
                  ..sort((a, b) => b.compareTo(a));
                final totalPages = sortedMonths.length;
                if (historyPage >= totalPages && totalPages > 0) {
                  historyPage = totalPages - 1;
                }
                final pageEntries = totalPages > 0
                    ? monthGroups[sortedMonths[historyPage]]!
                    : <_HistoryEntry>[];
                // Month names for header
                const monthNames = [
                  '',
                  'Enero',
                  'Febrero',
                  'Marzo',
                  'Abril',
                  'Mayo',
                  'Junio',
                  'Julio',
                  'Agosto',
                  'Septiembre',
                  'Octubre',
                  'Noviembre',
                  'Diciembre',
                ];
                final currentMonthLabel = totalPages > 0
                    ? monthNames[int.parse(
                        sortedMonths[historyPage].split('-')[1],
                      )]
                    : '';

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
                  ),
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.92,
                    maxChildSize: 0.95,
                    minChildSize: 0.5,
                    expand: false,
                    builder: (sheetCtx, scrollController) {
                      // ScaffoldMessenger/Scaffold wraps the draggable's rendered
                      // content (not the whole modal) so the Scaffold sizes to the
                      // draggable's current fraction — dragging down shrinks the
                      // Scaffold with it instead of leaving a blank wall behind.
                      return ScaffoldMessenger(
                        key: _sheetMessengerKey,
                        child: Scaffold(
                          backgroundColor: Colors.transparent,
                          resizeToAvoidBottomInset: false,
                          body: _buildRutaClientDetailSheet(
                            sheetCtx: sheetCtx,
                            scrollController: scrollController,
                            cliente: cliente,
                            cc: cc,
                            enLaCalle: enLaCalle,
                            entregasForClient: entregasForClient,
                            pago: pago,
                            totalOwed: totalOwed,
                            montoController: montoController,
                            panelMontoFocus: panelMontoFocus,
                            datosNombreController: datosNombreController,
                            datosTelefonoController: datosTelefonoController,
                            datosDireccionController: datosDireccionController,
                            datosNotasController: datosNotasController,
                            activeTab: activeTab,
                            setActiveTab: (tab) =>
                                setSheetState(() => activeTab = tab),
                            setSheetState: setSheetState,
                            markMontoEdited: () {
                              panelMontoManuallyEdited = true;
                            },
                            refreshCc: refreshCc,
                            commitMonto: commitPanelMonto,
                            loadHistory: loadHistory,
                            setHistoryEntries: (entries) =>
                                setSheetState(() => historyEntries = entries),
                            historyEntries: historyEntries,
                            pageEntries: pageEntries,
                            currentMonthLabel: currentMonthLabel,
                            historyPage: historyPage,
                            totalPages: totalPages,
                            goHistoryPage: (delta) {
                              setSheetState(() => historyPage += delta);
                            },
                          ),
                          /*
                      body: SingleChildScrollView(
                        controller: scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          20 + MediaQuery.of(sheetCtx).padding.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Handle
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: tokens.textMuted.withValues(
                                    alpha: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            // Header: number + name + phone
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${displayIndex + 1}',
                                  style: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: cliente.direccion.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () =>
                                              _navigateToClientOnMap(cliente),
                                          child: Text(
                                            cliente.direccion,
                                            style: TextStyle(
                                              color: tokens.primaryBlue,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: tokens
                                                  .primaryBlue
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          cliente.nombre,
                                          style: TextStyle(
                                            color: tokens.text,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                if (cliente.telefono.isNotEmpty)
                                  GestureDetector(
                                    onTap: () =>
                                        _showPhoneOptions(cliente.telefono),
                                    child: Icon(
                                      Icons.phone,
                                      color: tokens.textMuted,
                                      size: 22,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4),
                            // Info line: name · frecuencia
                            Padding(
                              padding: EdgeInsets.only(left: 28),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  if (cliente.direccion.isNotEmpty) ...[
                                    Text(
                                      cliente.nombre,
                                      style: TextStyle(
                                        color: tokens.text.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '·',
                                      style: TextStyle(
                                        color: tokens.text.withValues(
                                          alpha: 0.3,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                  Text(
                                    '${cliente.frecuencia[0].toUpperCase()}${cliente.frecuencia.substring(1)}',
                                    style: TextStyle(
                                      color: tokens.text.withValues(alpha: 0.5),
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (cliente.notas.isNotEmpty) ...[
                                    Text(
                                      '!',
                                      style: TextStyle(
                                        color: Colors.amber.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      cliente.notas,
                                      style: TextStyle(
                                        color: tokens.text.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Etiquetas
                            if (etiquetas.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Padding(
                                padding: EdgeInsets.only(left: 28),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: etiquetas
                                      .map(
                                        (e) =>
                                            _buildTag(e, _colorForEtiqueta(e)),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                            SizedBox(height: 16),
                            Divider(color: tokens.cardBorder),
                            SizedBox(height: 10),
                            // PRODUCTOS title + table header — only if there are products
                            if (_allProducts.isNotEmpty) ...[
                              Text(
                                'PRODUCTOS',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 10),
                              // Product table header
                              Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      'PRODUCTOS',
                                      style: TextStyle(
                                        color: tokens.text.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      'COMPRADO',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: tokens.text.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      'DEVUELTO',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: tokens.text.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '\$',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                            ],
                            // Product rows
                            ..._allProducts.map((product) {
                              final entrega = entregasForClient[product.id];
                              final entregado = entrega?.entregado ?? 0;
                              final devuelto = entrega?.devuelto ?? 0;
                              final clientSelections =
                                  _clientePrecioSelections[cliente.id];
                              final manualOverride =
                                  _overridePrices[cliente.id]?[product.id];
                              final hasManualPrice =
                                  manualOverride != null && manualOverride > 0;
                              final effectivePrice = hasManualPrice
                                  ? manualOverride
                                  : _getEffectivePrice(
                                      product.id,
                                      clientSelections,
                                    );
                              final precioLabel = _precioShortLabel(
                                product.id,
                                clientSelections,
                              );

                              return Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        _shortenProductName(product.nombre),
                                        style: TextStyle(
                                          color: tokens.text,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: _buildQtyControl(
                                        entregado,
                                        onMinus: () async {
                                          if (entregado > 0) {
                                            await _updateEntrega(
                                              cliente.id,
                                              product.id,
                                              entregado: entregado - 1,
                                            );
                                            setSheetState(() {});
                                          }
                                        },
                                        onPlus: () async {
                                          await _updateEntrega(
                                            cliente.id,
                                            product.id,
                                            entregado: entregado + 1,
                                          );
                                          setSheetState(() {});
                                        },
                                        onDirectInput: (v) async {
                                          await _updateEntrega(
                                            cliente.id,
                                            product.id,
                                            entregado: v,
                                          );
                                          setSheetState(() {});
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      flex: 5,
                                      child: _buildQtyControl(
                                        devuelto,
                                        onMinus: () async {
                                          if (devuelto > 0) {
                                            await _updateEntrega(
                                              cliente.id,
                                              product.id,
                                              devuelto: devuelto - 1,
                                            );
                                            setSheetState(() {});
                                          }
                                        },
                                        onPlus: () async {
                                          await _updateEntrega(
                                            cliente.id,
                                            product.id,
                                            devuelto: devuelto + 1,
                                          );
                                          setSheetState(() {});
                                        },
                                        onDirectInput: (v) async {
                                          await _updateEntrega(
                                            cliente.id,
                                            product.id,
                                            devuelto: v,
                                          );
                                          setSheetState(() {});
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _showPriceSelector(
                                        product,
                                        cliente.id,
                                        setSheetState,
                                      ),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: hasManualPrice
                                              ? tokens.warn.withValues(
                                                  alpha: 0.25,
                                                )
                                              : Color(
                                                  0xFF4D609B,
                                                ).withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: hasManualPrice
                                              ? Border.all(
                                                  color: tokens.warn.withValues(
                                                    alpha: 0.7,
                                                  ),
                                                  width: 1,
                                                )
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            precioLabel,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: hasManualPrice
                                                  ? tokens.warn
                                                  : effectivePrice > 0
                                                  ? tokens.textSub
                                                  : Color(
                                                      0xFF7B8EC2,
                                                    ).withValues(alpha: 0.5),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            SizedBox(height: 8),
                            Divider(color: tokens.cardBorder),
                            SizedBox(height: 12),
                            // CUENTA CORRIENTE (left) + EN POSESIÓN (right)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CUENTA CORRIENTE',
                                        style: TextStyle(
                                          color: tokens.text.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        isMoneyPositive(cc)
                                            ? '-\$${cc.toStringAsFixed(0)}'
                                            : '\$${cc.abs().toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: !isMoneyNegative(cc)
                                              ? tokens.success
                                              : tokens.danger,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (enLaCalle.isNotEmpty)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'EN POSESIÓN',
                                          style: TextStyle(
                                            color: tokens.text.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        ...enLaCalle.entries.map((e) {
                                          final pName =
                                              _productMap[e.key]?.nombre ?? '?';
                                          final size = _productPackSizes[e.key];
                                          final displayQty = formatPackQty(
                                            e.value,
                                            size,
                                          );
                                          return Padding(
                                            padding: EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: tokens.primaryBlue
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: tokens.primaryBlue
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                    ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    displayQty,
                                                    style: TextStyle(
                                                      color: tokens.text,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    pName,
                                                    style: TextStyle(
                                                      color: tokens.text
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            // PAGO — full width
                            SizedBox(height: 16),
                            Text(
                              'PAGO',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                _buildPaymentButton(
                                  Icons.payments_outlined,
                                  pago?.metodoPago == 'efectivo',
                                  () {
                                    if (_isPagoUndoTap(
                                      cliente.id,
                                      'efectivo',
                                    )) {
                                      _removePago(
                                        cliente.id,
                                      ).then((_) => refreshCc());
                                      return;
                                    }
                                    final monto =
                                        parseArgNumber(montoController.text) ??
                                        0;
                                    if (monto <= 0) {
                                      _showMontoWarning();
                                      return;
                                    }
                                    _setPago(
                                      cliente.id,
                                      'efectivo',
                                      monto,
                                    ).then((ok) async {
                                      if (!ok) return;
                                      _provisionalPagoClientes.remove(
                                        cliente.id,
                                      );
                                      refreshCc();
                                      final completed =
                                          await _maybeAutoCompleteOnPago(cliente.id);
                                      if (completed && sheetCtx.mounted) {
                                        Navigator.of(sheetCtx).pop();
                                      }
                                    });
                                  },
                                  height: 38,
                                  radius: 8,
                                  width: 42,
                                  iconSize: 20,
                                ),
                                SizedBox(width: 6),
                                _buildPaymentButton(
                                  Icons.phone_android,
                                  pago?.metodoPago == 'transferencia',
                                  () {
                                    if (_isPagoUndoTap(
                                      cliente.id,
                                      'transferencia',
                                    )) {
                                      _removePago(
                                        cliente.id,
                                      ).then((_) => refreshCc());
                                      return;
                                    }
                                    final monto =
                                        parseArgNumber(montoController.text) ??
                                        0;
                                    if (monto <= 0) {
                                      _showMontoWarning();
                                      return;
                                    }
                                    _setPago(
                                      cliente.id,
                                      'transferencia',
                                      monto,
                                    ).then((ok) async {
                                      if (!ok) return;
                                      _provisionalPagoClientes.remove(
                                        cliente.id,
                                      );
                                      refreshCc();
                                      final completed =
                                          await _maybeAutoCompleteOnPago(
                                            cliente.id,
                                          );
                                      if (completed && sheetCtx.mounted) {
                                        Navigator.of(sheetCtx).pop();
                                      }
                                    });
                                  },
                                  height: 38,
                                  radius: 8,
                                  width: 42,
                                  iconSize: 20,
                                ),
                                SizedBox(width: 6),
                                _buildPaymentButton(
                                  Icons.not_interested,
                                  pago?.metodoPago == 'no_pago',
                                  () {
                                    if (_isPagoUndoTap(
                                      cliente.id,
                                      'no_pago',
                                    )) {
                                      _removePago(
                                        cliente.id,
                                      ).then((_) => refreshCc());
                                      return;
                                    }
                                    _setPago(
                                      cliente.id,
                                      'no_pago',
                                      totalOwed,
                                    ).then((ok) async {
                                      if (!ok) return;
                                      _provisionalPagoClientes.remove(
                                        cliente.id,
                                      );
                                      refreshCc();
                                      final completed =
                                          await _maybeAutoCompleteOnPago(
                                            cliente.id,
                                          );
                                      if (completed && sheetCtx.mounted) {
                                        Navigator.of(sheetCtx).pop();
        _openNextPendingPanelAfter(cliente.id);
                                      }
                                    });
                                  },
                                  height: 38,
                                  radius: 8,
                                  width: 42,
                                  iconSize: 20,
                                ),
                                if (_qrEnabled) ...[
                                  SizedBox(width: 6),
                                  _buildPaymentButton(
                                    Icons.qr_code,
                                    false,
                                    () {
                                      final monto =
                                          parseArgNumber(
                                            montoController.text,
                                          )?.toDouble() ??
                                          totalOwed;
                                      _showMpQrDialog(
                                        cliente.id,
                                        monto,
                                        cliente.nombre,
                                      );
                                    },
                                    height: 38,
                                    radius: 8,
                                    width: 42,
                                    iconSize: 20,
                                  ),
                                ],
                                SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: Builder(
                                      builder: (fieldCtx) => TextField(
                                        controller: montoController,
                                        focusNode: panelMontoFocus,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.,]'),
                                          ),
                                        ],
                                        onTap: () {
                                          panelMontoManuallyEdited = true;
                                          if (montoController.text.isNotEmpty) {
                                            for (final ms in [50, 100, 200]) {
                                              Future.delayed(
                                                Duration(milliseconds: ms),
                                                () {
                                                  if (montoController
                                                      .text
                                                      .isNotEmpty) {
                                                    montoController.selection =
                                                        TextSelection.collapsed(
                                                          offset:
                                                              montoController
                                                                  .text
                                                                  .length,
                                                        );
                                                  }
                                                },
                                              );
                                            }
                                          }
                                          Future.delayed(
                                            Duration(milliseconds: 400),
                                            () {
                                              Scrollable.ensureVisible(
                                                fieldCtx,
                                                duration: Duration(
                                                  milliseconds: 300,
                                                ),
                                                curve: Curves.easeInOut,
                                                alignmentPolicy:
                                                    ScrollPositionAlignmentPolicy
                                                        .keepVisibleAtEnd,
                                              );
                                            },
                                          );
                                        },
                                        onChanged: (val) {
                                          panelMontoManuallyEdited = true;
                                          final currentPago =
                                              _clientePagos[cliente.id];
                                          _rememberEditingPagoMethod(
                                            cliente.id,
                                            currentPago?.metodoPago,
                                          );
                                          final action =
                                              resolvePaymentEditAction(
                                                rawMonto: val,
                                                currentMetodoPago:
                                                    currentPago?.metodoPago,
                                                rememberedMetodoPago:
                                                    _rememberedEditingPagoMethod(
                                                      cliente.id,
                                                    ),
                                                commit: false,
                                              );
                                          if (action.kind ==
                                              PaymentEditActionKind.save) {
                                            _setPago(
                                              cliente.id,
                                              action.metodoPago!,
                                              action.monto,
                                            ).then((ok) {
                                              if (ok) refreshCc();
                                            });
                                          }
                                        },
                                        textAlignVertical:
                                            TextAlignVertical.center,
                                        style: TextStyle(
                                          color: tokens.text,
                                          fontSize: 14,
                                          height: 1,
                                        ),
                                        decoration: InputDecoration(
                                          prefixText: '\$ ',
                                          prefixStyle: TextStyle(
                                            color: tokens.text.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontSize: 14,
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          isDense: true,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(
                                                0xFF4D609B,
                                              ).withValues(alpha: 0.5),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: tokens.primaryBlue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // NOTAS
                            SizedBox(height: 16),
                            Text(
                              'NOTAS',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              cliente.notas.isNotEmpty ? cliente.notas : '—',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 16),
                            Divider(color: tokens.cardBorder),
                            SizedBox(height: 12),
                            // HISTORIAL (full width, 2-col grid per month).
                            // Wrapped in a horizontal-drag detector so swiping
                            // left/right flips the month page — the < / >
                            // buttons below still work for tap users.
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragEnd: (details) {
                                if (totalPages <= 1) return;
                                final vx = details.velocity.pixelsPerSecond.dx;
                                if (vx.abs() < 250) return;
                                if (vx > 0 && historyPage > 0) {
                                  setSheetState(() => historyPage--);
                                } else if (vx < 0 &&
                                    historyPage < totalPages - 1) {
                                  setSheetState(() => historyPage++);
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'HISTORIAL',
                                        style: TextStyle(
                                          color: tokens.text.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (currentMonthLabel.isNotEmpty) ...[
                                        SizedBox(width: 8),
                                        Text(
                                          currentMonthLabel,
                                          style: TextStyle(
                                            color: tokens.text.withValues(
                                              alpha: 0.3,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      Spacer(),
                                      GestureDetector(
                                        onTap: () => _showAddHistoryDialog(
                                          cliente,
                                          setSheetState,
                                          () async {
                                            final entries = await loadHistory();
                                            setSheetState(
                                              () => historyEntries = entries,
                                            );
                                          },
                                        ),
                                        child: Icon(
                                          Icons.add_circle_outline,
                                          color: tokens.text.withValues(
                                            alpha: 0.4,
                                          ),
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  if (historyEntries.isEmpty)
                                    Text(
                                      'Sin historial',
                                      style: TextStyle(
                                        color: tokens.text.withValues(
                                          alpha: 0.3,
                                        ),
                                        fontSize: 12,
                                      ),
                                    )
                                  else ...[
                                    // 2-column grid, rows of 2
                                    for (
                                      int row = 0;
                                      row < ((pageEntries.length + 1) ~/ 2);
                                      row++
                                    ) ...[
                                      if (row > 0) SizedBox(height: 6),
                                      Row(
                                        children: [
                                          for (int col = 0; col < 2; col++) ...[
                                            if (col > 0) SizedBox(width: 6),
                                            Expanded(
                                              child: Builder(
                                                builder: (context) {
                                                  final idx = row * 2 + col;
                                                  if (idx >=
                                                      pageEntries.length) {
                                                    return SizedBox(height: 70);
                                                  }
                                                  final entry =
                                                      pageEntries[idx];
                                                  return Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        _showEditHistoryForEntry(
                                                          cliente,
                                                          entry,
                                                          setSheetState,
                                                          () async {
                                                            final entries =
                                                                await loadHistory();
                                                            setSheetState(
                                                              () =>
                                                                  historyEntries =
                                                                      entries,
                                                            );
                                                          },
                                                        );
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: Container(
                                                        constraints:
                                                            BoxConstraints(
                                                              minHeight: 74,
                                                            ),
                                                        padding:
                                                            EdgeInsets.fromLTRB(
                                                              6,
                                                              6,
                                                              6,
                                                              8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Color(
                                                            0xFF0A1525,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color: tokens.text
                                                                .withValues(
                                                                  alpha: 0.06,
                                                                ),
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            // Header: day+date left, total right
                                                            Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Text(
                                                                  '${entry.dayAbbr} ${entry.dateLabel}',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white
                                                                        .withValues(
                                                                          alpha:
                                                                              0.6,
                                                                        ),
                                                                    fontSize: 9,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ),
                                                                if (entry.metodoPago ==
                                                                        'no_pago' ||
                                                                    (entry.monto <=
                                                                            0 &&
                                                                        !entry
                                                                            .noCompro &&
                                                                        !entry
                                                                            .ausente &&
                                                                        !entry
                                                                            .saltado &&
                                                                        entry.totalOwed >
                                                                            0))
                                                                  Text(
                                                                    '\$${entry.totalOwed.toStringAsFixed(0)}',
                                                                    style: TextStyle(
                                                                      color: tokens
                                                                          .danger,
                                                                      fontSize:
                                                                          9,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                    ),
                                                                  )
                                                                else if (entry
                                                                        .monto >
                                                                    0)
                                                                  Text.rich(
                                                                    TextSpan(
                                                                      children: [
                                                                        TextSpan(
                                                                          text:
                                                                              '\$${entry.monto.toStringAsFixed(0)}',
                                                                          style: TextStyle(
                                                                            color:
                                                                                tokens.success,
                                                                            fontSize:
                                                                                9,
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                          ),
                                                                        ),
                                                                        if (entry.deuda >
                                                                            0)
                                                                          TextSpan(
                                                                            text:
                                                                                ' -\$${entry.deuda.toStringAsFixed(0)}',
                                                                            style: TextStyle(
                                                                              color: tokens.danger,
                                                                              fontSize: 8,
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                            SizedBox(height: 2),
                                                            if (entry.ausente)
                                                              Text(
                                                                'Ausente',
                                                                style: TextStyle(
                                                                  color:
                                                                      Color(
                                                                        0xFFFF9800,
                                                                      ).withValues(
                                                                        alpha:
                                                                            0.7,
                                                                      ),
                                                                  fontSize: 9,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                              )
                                                            else if (entry
                                                                .saltado)
                                                              Text(
                                                                'Saltado',
                                                                style: TextStyle(
                                                                  color: tokens
                                                                      .primaryBlue
                                                                      .withValues(
                                                                        alpha:
                                                                            0.7,
                                                                      ),
                                                                  fontSize: 9,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                              )
                                                            else if (entry
                                                                .noCompro)
                                                              Text(
                                                                'No compró',
                                                                style: TextStyle(
                                                                  color: tokens
                                                                      .danger
                                                                      .withValues(
                                                                        alpha:
                                                                            0.7,
                                                                      ),
                                                                  fontSize: 9,
                                                                  fontStyle:
                                                                      FontStyle
                                                                          .italic,
                                                                ),
                                                              )
                                                            else ...[
                                                              // Bottom row: green up arrows (bought) - horizontal
                                                              Row(
                                                                children: entry
                                                                    .deliveries
                                                                    .where(
                                                                      (d) =>
                                                                          d.entregado >
                                                                          0,
                                                                    )
                                                                    .expand(
                                                                      (d) => [
                                                                        Icon(
                                                                          Icons
                                                                              .arrow_upward,
                                                                          size:
                                                                              9,
                                                                          color:
                                                                              tokens.success,
                                                                        ),
                                                                        Text(
                                                                          '${d.entregado}',
                                                                          style: TextStyle(
                                                                            color:
                                                                                tokens.success,
                                                                            fontSize:
                                                                                9,
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              2,
                                                                        ),
                                                                        Flexible(
                                                                          child: Text(
                                                                            d.productName,
                                                                            style: TextStyle(
                                                                              color: tokens.text.withValues(
                                                                                alpha: 0.45,
                                                                              ),
                                                                              fontSize: 8,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                      ],
                                                                    )
                                                                    .toList(),
                                                              ),
                                                              // Upper row: red down arrows (returns) - horizontal
                                                              if (entry
                                                                  .deliveries
                                                                  .any(
                                                                    (d) =>
                                                                        d.devuelto >
                                                                        0,
                                                                  ))
                                                                Row(
                                                                  children: entry
                                                                      .deliveries
                                                                      .where(
                                                                        (d) =>
                                                                            d.devuelto >
                                                                            0,
                                                                      )
                                                                      .expand(
                                                                        (d) => [
                                                                          Icon(
                                                                            Icons.arrow_downward,
                                                                            size:
                                                                                9,
                                                                            color:
                                                                                tokens.danger,
                                                                          ),
                                                                          Text(
                                                                            '${d.devuelto}',
                                                                            style: TextStyle(
                                                                              color: tokens.danger,
                                                                              fontSize: 9,
                                                                              fontWeight: FontWeight.w700,
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width:
                                                                                2,
                                                                          ),
                                                                          Flexible(
                                                                            child: Text(
                                                                              d.productName,
                                                                              style: TextStyle(
                                                                                color: tokens.text.withValues(
                                                                                  alpha: 0.45,
                                                                                ),
                                                                                fontSize: 8,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width:
                                                                                4,
                                                                          ),
                                                                        ],
                                                                      )
                                                                      .toList(),
                                                                ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                    // Pagination: < Month >
                                    if (totalPages > 1)
                                      Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: historyPage > 0
                                                  ? () => setSheetState(
                                                      () => historyPage--,
                                                    )
                                                  : null,
                                              child: Text(
                                                '<',
                                                style: TextStyle(
                                                  color: historyPage > 0
                                                      ? tokens.textMuted
                                                      : tokens.cardBorder,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              currentMonthLabel,
                                              style: TextStyle(
                                                color: tokens.textSub,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            GestureDetector(
                                              onTap:
                                                  historyPage < totalPages - 1
                                                  ? () => setSheetState(
                                                      () => historyPage++,
                                                    )
                                                  : null,
                                              child: Text(
                                                '>',
                                                style: TextStyle(
                                                  color:
                                                      historyPage <
                                                          totalPages - 1
                                                      ? tokens.textMuted
                                                      : tokens.cardBorder,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            // Status action buttons
                            SizedBox(height: 16),
                            Row(
                              children: [
                                // No compró (left)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_getClientStatus(cliente.id) ==
                                          'skipped') {
                                        unawaited(
                                          _setClientStatus(
                                            cliente.id,
                                            'pending',
                                          ),
                                        );
                                        setSheetState(() {});
                                        return;
                                      }
                                      if (_hasUnconfirmedPayment(cliente.id)) {
                                        _showPaymentMethodWarning();
                                        return;
                                      }
                                      unawaited(
                                        _setClientStatus(cliente.id, 'skipped'),
                                      );
                                      setSheetState(() {});
                                    },
                                    child: Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            _getClientStatus(cliente.id) ==
                                                'skipped'
                                            ? tokens.danger.withValues(
                                                alpha: 0.2,
                                              )
                                            : tokens.text.withValues(
                                                alpha: 0.08,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              _getClientStatus(cliente.id) ==
                                                  'skipped'
                                              ? tokens.danger
                                              : tokens.text.withValues(
                                                  alpha: 0.25,
                                                ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.close,
                                              size: 13,
                                              color:
                                                  _getClientStatus(
                                                        cliente.id,
                                                      ) ==
                                                      'skipped'
                                                  ? tokens.danger
                                                  : tokens.textSub,
                                            ),
                                            SizedBox(width: 2),
                                            Flexible(
                                              child: Text(
                                                'No compró',
                                                style: TextStyle(
                                                  color:
                                                      _getClientStatus(
                                                            cliente.id,
                                                          ) ==
                                                          'skipped'
                                                      ? tokens.danger
                                                      : tokens.textSub,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 5),
                                // Ausente
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_getClientStatus(cliente.id) ==
                                          'absent') {
                                        unawaited(
                                          _setClientStatus(
                                            cliente.id,
                                            'pending',
                                          ),
                                        );
                                        setSheetState(() {});
                                        return;
                                      }
                                      if (_hasUnconfirmedPayment(cliente.id)) {
                                        _showPaymentMethodWarning();
                                        return;
                                      }
                                      unawaited(
                                        _setClientStatus(cliente.id, 'absent'),
                                      );
                                      setSheetState(() {});
                                    },
                                    child: Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            _getClientStatus(cliente.id) ==
                                                'absent'
                                            ? tokens.warn.withValues(alpha: 0.2)
                                            : tokens.text.withValues(
                                                alpha: 0.08,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              _getClientStatus(cliente.id) ==
                                                  'absent'
                                              ? tokens.warn
                                              : tokens.text.withValues(
                                                  alpha: 0.25,
                                                ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.question_mark,
                                              size: 12,
                                              color:
                                                  _getClientStatus(
                                                        cliente.id,
                                                      ) ==
                                                      'absent'
                                                  ? tokens.warn
                                                  : tokens.textSub,
                                            ),
                                            SizedBox(width: 2),
                                            Text(
                                              'Ausente',
                                              style: TextStyle(
                                                color:
                                                    _getClientStatus(
                                                          cliente.id,
                                                        ) ==
                                                        'absent'
                                                    ? tokens.warn
                                                    : tokens.textSub,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Saltar — hidden once this cliente has any visit
                                // activity today. It reappears only after the
                                // activity is fully undone.
                                if (!_hasVisitActivity(cliente.id)) ...[
                                  SizedBox(width: 5),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        unawaited(
                                          _setClientStatus(
                                            cliente.id,
                                            _getClientStatus(cliente.id) ==
                                                    'deferred'
                                                ? 'pending'
                                                : 'deferred',
                                          ),
                                        );
                                        setSheetState(() {});
                                      },
                                      child: Container(
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color:
                                              _getClientStatus(cliente.id) ==
                                                  'deferred'
                                              ? tokens.primaryBlue.withValues(
                                                  alpha: 0.15,
                                                )
                                              : tokens.text.withValues(
                                                  alpha: 0.08,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color:
                                                _getClientStatus(cliente.id) ==
                                                    'deferred'
                                                ? tokens.primaryBlue
                                                : tokens.text.withValues(
                                                    alpha: 0.25,
                                                  ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.remove,
                                                size: 13,
                                                color:
                                                    _getClientStatus(
                                                          cliente.id,
                                                        ) ==
                                                        'deferred'
                                                    ? tokens.primaryBlue
                                                    : tokens.textSub,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'Saltar',
                                                style: TextStyle(
                                                  color:
                                                      _getClientStatus(
                                                            cliente.id,
                                                          ) ==
                                                          'deferred'
                                                      ? tokens.primaryBlue
                                                      : tokens.textSub,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(width: 5),
                                // Entregado (right)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_getClientStatus(cliente.id) ==
                                          'completed') {
                                        unawaited(
                                          _setClientStatus(
                                            cliente.id,
                                            'pending',
                                          ),
                                        );
                                        setSheetState(() {});
                                        return;
                                      }
                                      if (_hasUnconfirmedPayment(cliente.id)) {
                                        _showPaymentMethodWarning();
                                        return;
                                      }
                                      unawaited(
                                        _setClientStatus(
                                          cliente.id,
                                          'completed',
                                        ),
                                      );
                                      setSheetState(() {});
                                    },
                                    child: Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            _getClientStatus(cliente.id) ==
                                                'completed'
                                            ? tokens.success.withValues(
                                                alpha: 0.2,
                                              )
                                            : tokens.text.withValues(
                                                alpha: 0.08,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              _getClientStatus(cliente.id) ==
                                                  'completed'
                                              ? tokens.success
                                              : tokens.text.withValues(
                                                  alpha: 0.25,
                                                ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check,
                                              size: 13,
                                              color:
                                                  _getClientStatus(
                                                        cliente.id,
                                                      ) ==
                                                      'completed'
                                                  ? tokens.success
                                                  : tokens.textSub,
                                            ),
                                            SizedBox(width: 2),
                                            Flexible(
                                              child: Text(
                                                'Listo',
                                                style: TextStyle(
                                                  color:
                                                      _getClientStatus(
                                                            cliente.id,
                                                          ) ==
                                                          'completed'
                                                      ? tokens.success
                                                      : tokens.textSub,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                            Divider(color: tokens.cardBorder),
                            SizedBox(height: 12),
                            // ACCIONES
                            Text(
                              'ACCIONES',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _generateFactura(cliente);
                                    },
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: tokens.success.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: tokens.success.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              'GENERAR FACTURACIÓN',
                                              style: TextStyle(
                                                color: tokens.text,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FacturasScreen(
                                            clienteId: cliente.id,
                                            clienteNombre: cliente.nombre,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: tokens.primaryBlue.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: tokens.primaryBlue.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              'VER FACTURAS',
                                              style: TextStyle(
                                                color: tokens.text,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showCambiarDia(cliente, setSheetState),
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: tokens.primaryBlue.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: tokens.primaryBlue.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              'CAMBIAR DE DIA',
                                              style: TextStyle(
                                                color: tokens.text,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _confirmDarDeBaja(cliente),
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: tokens.danger.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: tokens.danger.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              'DAR DE BAJA',
                                              style: TextStyle(
                                                color: tokens.text,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                      */
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        )
        .whenComplete(() {
          sheetMounted = false;
        })
        .then((_) async {
          TutorialController.instance.onClientDetailClosed();
          datosDebounce?.cancel();
          await saveDatos();
          // Issue 4: catch dismissal without unfocus — commit any pending monto
          // edit before the controller is disposed and the panel is gone.
          if (panelMontoManuallyEdited) {
            await commitPanelMonto();
          }
          if (!_draftClienteIds.contains(cliente.id)) {
            await _loadData();
          } else if (mounted) {
            setState(() {});
            _emitStats();
          }
          // Defer FocusNode / Controller disposal one frame so any in-flight
          // TextField rebuild (the sheet's closing animation, or a setState queued
          // by commitPanelMonto / _loadData) still sees a live focus node. Without
          // this we hit "FocusNode used after being disposed" from inside
          // _AnimatedState.didUpdateWidget when the merged focus+animation
          // listenable re-registers on the just-disposed node.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(Duration(milliseconds: 400), () {
              for (final ctrl in [
                datosNombreController,
                datosTelefonoController,
                datosDireccionController,
                datosNotasController,
              ]) {
                ctrl.removeListener(scheduleDatosSave);
                ctrl.dispose();
              }
              panelMontoFocus.dispose();
              panelMontoController.dispose();
            });
          });
        });
  }

  BoxDecoration _rutaWhiteCardDeco({double radius = 16}) => BoxDecoration(
    color: tokens.card,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 1)),
    ],
  );

  String _formatRutaMoney(double amount) {
    final raw = amount.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final remaining = raw.length - i;
      buffer.write(raw[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('.');
    }
    final formatted = buffer.toString();
    if (amount < 0) return '- \$$formatted';
    return '\$$formatted';
  }

  String _rutaShortProductName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    // Explicit overrides that need disambiguation (two sifón sizes share
    // the same volume so we keep the type hint).
    switch (trimmed) {
      case 'Sifón vidrio 1L':
        return 'Sif. V';
      case 'Sifón plástico 1.5L':
        return 'Sif. P';
      case 'Dispenser F/C':
        return 'Disp.';
    }
    // Heuristic 1: extract a volume token (digits + optional decimal + L).
    // Works for "Botellón 20L", "Bidón 20 L", "Botellones 12L", etc.
    final volMatch = RegExp(
      r'\d+(?:[.,]\d+)?\s*[Ll](?![A-Za-z])',
    ).firstMatch(trimmed);
    if (volMatch != null) {
      return volMatch.group(0)!.replaceAll(' ', '').toUpperCase();
    }
    // Heuristic 2: first word, capped at 8 chars (better than mid-word
    // cut). E.g. "Dispenser" → "Dispense", "Soda 2L" already handled by
    // the regex.
    final firstWord = trimmed.split(' ').first;
    return firstWord.length <= 8 ? firstWord : firstWord.substring(0, 8);
  }

  Color _rutaProductTint(int productId) {
    const colors = [
      Color(0xFF1292D3),
      Color(0xFF2ECC71),
      Color(0xFFE67E22),
      Color(0xFF9B59B6),
      Color(0xFFE74C3C),
      Color(0xFF1ABC9C),
    ];
    return colors[productId.abs() % colors.length];
  }

  Widget _rutaSectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Future<void> _openRutaWhatsapp(BuildContext sheetCtx, Cliente cliente) async {
    showDemoUpgradeSnack(
      sheetCtx,
      message: 'WhatsApp no esta disponible en la demo.',
    );
  }

  Widget _buildRutaClientDetailSheet({
    required BuildContext sheetCtx,
    required ScrollController scrollController,
    required Cliente cliente,
    required double cc,
    required Map<int, int> enLaCalle,
    required Map<int, Entrega> entregasForClient,
    required Pago? pago,
    required double totalOwed,
    required TextEditingController montoController,
    required FocusNode panelMontoFocus,
    required TextEditingController datosNombreController,
    required TextEditingController datosTelefonoController,
    required TextEditingController datosDireccionController,
    required TextEditingController datosNotasController,
    required int activeTab,
    required ValueChanged<int> setActiveTab,
    required StateSetter setSheetState,
    required VoidCallback markMontoEdited,
    required Future<void> Function() refreshCc,
    required Future<bool> Function() commitMonto,
    required Future<List<_HistoryEntry>> Function() loadHistory,
    required ValueChanged<List<_HistoryEntry>> setHistoryEntries,
    required List<_HistoryEntry> historyEntries,
    required List<_HistoryEntry> pageEntries,
    required String currentMonthLabel,
    required int historyPage,
    required int totalPages,
    required ValueChanged<int> goHistoryPage,
  }) {
    final readOnly = kDemoMode && !kDemoAllowLiveFlow;
    final configuredHabitualIds =
        (_clienteProducts[cliente.id] ?? <ClienteProducto>[])
            .where((cp) => cp.cantidadHabitual > 0)
            .map((cp) => cp.productoId)
            .toList();
    final topProductIds = configuredHabitualIds.isNotEmpty
        ? configuredHabitualIds
        : (_clientTopProducts[cliente.id] ?? <int>[]);
    final activityIds = entregasForClient.entries
        .where((e) => e.value.entregado > 0 || e.value.devuelto > 0)
        .map((e) => e.key)
        .toSet();
    final habitualIds = <int>{
      ...topProductIds.where(_productMapIncludingDeleted.containsKey),
      ...activityIds.where((id) => topProductIds.contains(id)),
    };
    final habitualProducts = _allProductsIncludingDeleted
        .where((p) => habitualIds.contains(p.id))
        .toList();
    final adicionalProducts = _allProducts
        .where((p) => !habitualIds.contains(p.id))
        .toList();
    final ccColor = isMoneyNegative(cc)
        ? tokens.danger
        : isMoneyPositive(cc)
        ? tokens.success
        : tokens.text;
    final ccSubtitle = isMoneyNegative(cc)
        ? 'En deuda'
        : isMoneyPositive(cc)
        ? 'A favor'
        : 'Al día';

    Future<void> selectPago(String metodo) async {
      if (readOnly && blockDemoAction(context)) return;
      if (_isPagoUndoTap(cliente.id, metodo)) {
        await _removePago(cliente.id);
        await refreshCc();
        return;
      }
      final monto = metodo == 'no_pago'
          ? totalOwed
          : (parseArgNumber(montoController.text) ?? 0).toDouble();
      if (metodo != 'no_pago' && monto <= 0) {
        _showMontoWarning();
        return;
      }
      final ok = await _setPago(cliente.id, metodo, monto);
      if (!ok) return;
      _provisionalPagoClientes.remove(cliente.id);
      await refreshCc();
      final completed = await _maybeAutoCompleteOnPago(cliente.id);
      if (completed && sheetCtx.mounted) {
        Navigator.of(sheetCtx).pop();
        _openNextPendingPanelAfter(cliente.id);
      }
    }

    Future<void> setStatus(String status) async {
      if (readOnly && blockDemoAction(context)) return;
      final current = _getClientStatus(cliente.id);
      if (current == status) {
        // Toggle-off-to-pending: user is undoing the previous status, likely
        // because they hit the wrong button. Keep the sheet open so they can
        // pick the correct one without re-navigating.
        unawaited(_setClientStatus(cliente.id, 'pending'));
        setSheetState(() {});
        return;
      }
      if (status != 'deferred') {
        final saved = await commitMonto();
        if (!saved || !sheetCtx.mounted) return;
      }
      if (status != 'deferred' && _hasUnconfirmedPayment(cliente.id)) {
        // Gate fired (unconfirmed monto). Snackbar tells the user what to
        // fix; sheet stays open so they can complete the pago first.
        _showPaymentMethodWarning();
        return;
      }
      if (status == 'deferred') {
        final confirmed = await _confirmSaltarIfActivity(
          cliente.id,
          dialogContext: sheetCtx,
        );
        if (!confirmed || !sheetCtx.mounted) return;
      }
      // Forward progress: a new status was successfully applied. By this
      // point the sodero has already entered any entregas/pagos they
      // needed, so close the sheet and abrir el panel del próximo cliente
      // pendiente — igual que selectPago / auto-Listo. Aplica a cualquier
      // estado (Ausente / Saltar / Listo), no sólo a Listo.
      unawaited(_setClientStatus(cliente.id, status));
      if (sheetCtx.mounted) {
        Navigator.of(sheetCtx).pop();
      }
      _openNextPendingPanelAfter(cliente.id);
    }

    return Column(
      children: [
        _buildRutaStickyBar(sheetCtx, cliente),
        Expanded(
          child: ListView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 14, 16, 18),
            children: [
              _buildRutaHeroCard(
                sheetCtx: sheetCtx,
                cliente: cliente,
                cc: cc,
                ccColor: ccColor,
                ccSubtitle: ccSubtitle,
                enLaCalle: enLaCalle,
                activeTab: activeTab,
                setActiveTab: setActiveTab,
              ),
              SizedBox(height: 16),
              if (activeTab == 0) ...[
                _rutaSectionLabel('VENTA'),
                SizedBox(height: 8),
                _buildRutaProductCard(
                  cliente: cliente,
                  title: 'Habitual',
                  subtitle: 'Productos del pedido frecuente',
                  products: habitualProducts,
                  entregasForClient: entregasForClient,
                  qtyColor: tokens.primaryBlue,
                  plusColor: tokens.primaryBlue,
                  setSheetState: setSheetState,
                  readOnly: readOnly,
                ),
                SizedBox(height: 14),
                _buildRutaProductCard(
                  cliente: cliente,
                  title: 'Comprado adicional',
                  subtitle: 'Sumá productos fuera del pedido habitual',
                  products: adicionalProducts,
                  entregasForClient: entregasForClient,
                  qtyColor: tokens.success,
                  plusColor: tokens.success,
                  setSheetState: setSheetState,
                  readOnly: readOnly,
                ),
                SizedBox(height: 18),
                _rutaSectionLabel('PAGO'),
                SizedBox(height: 8),
                _buildRutaPaymentCard(
                  cliente: cliente,
                  pago: pago,
                  totalOwed: totalOwed,
                  montoController: montoController,
                  panelMontoFocus: panelMontoFocus,
                  markMontoEdited: markMontoEdited,
                  refreshCc: refreshCc,
                  selectPago: selectPago,
                  readOnly: readOnly,
                ),
                SizedBox(height: 18),
                _rutaSectionLabel('ACCIONES'),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (readOnly && blockDemoAction(context)) return;
                          Navigator.pop(sheetCtx);
                          _generateFactura(cliente);
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tokens.success.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  'GENERAR FACTURACIÓN',
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FacturasScreen(
                                clienteId: cliente.id,
                                clienteNombre: cliente.nombre,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.primaryBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tokens.primaryBlue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  'VER FACTURAS',
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (activeTab == 1) ...[
                _rutaSectionLabel('DATOS'),
                SizedBox(height: 8),
                _buildRutaDatosCard(
                  cliente: cliente,
                  nombreController: datosNombreController,
                  telefonoController: datosTelefonoController,
                  direccionController: datosDireccionController,
                  notasController: datosNotasController,
                  readOnly: readOnly,
                ),
                SizedBox(height: 18),
                _rutaSectionLabel('ACCIONES'),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (readOnly && blockDemoAction(context)) return;
                          _showCambiarDia(cliente, setSheetState);
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.primaryBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tokens.primaryBlue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  'CAMBIAR DE DIA',
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (readOnly && blockDemoAction(context)) return;
                          _confirmDarDeBaja(cliente);
                        },
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: tokens.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tokens.danger.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  'DAR DE BAJA',
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _rutaSectionLabel('HISTORIAL'),
                SizedBox(height: 8),
                _buildRutaHistoryCard(
                  cliente: cliente,
                  setSheetState: setSheetState,
                  loadHistory: loadHistory,
                  setHistoryEntries: setHistoryEntries,
                  historyEntries: historyEntries,
                  pageEntries: pageEntries,
                  currentMonthLabel: currentMonthLabel,
                  historyPage: historyPage,
                  totalPages: totalPages,
                  goHistoryPage: goHistoryPage,
                  readOnly: readOnly,
                ),
              ],
            ],
          ),
        ),
        _buildRutaFooter(
          totalOwed: totalOwed,
          onAbsent: () => unawaited(setStatus('absent')),
          onSkip: () => unawaited(setStatus('deferred')),
          onDone: () => unawaited(setStatus('completed')),
          currentStatus: _getClientStatus(cliente.id),
        ),
      ],
    );
  }

  Widget _buildRutaStickyBar(BuildContext sheetCtx, Cliente cliente) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(bottom: BorderSide(color: tokens.cardBorder, width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      // Stack centers the title in the full bar width regardless of the
      // back-button's rendered size. Previously a Row + Expanded(Text)
      // centered the title only within the space remaining AFTER the back
      // button, which biased it slightly right of the bar's true center.
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(sheetCtx),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: tokens.text,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Text(
            'Visita',
            style: TextStyle(
              color: tokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRutaHeroCard({
    required BuildContext sheetCtx,
    required Cliente cliente,
    required double cc,
    required Color ccColor,
    required String ccSubtitle,
    required Map<int, int> enLaCalle,
    required int activeTab,
    required ValueChanged<int> setActiveTab,
  }) {
    final address = cliente.direccion.trim().isNotEmpty
        ? cliente.direccion.trim()
        : 'Sin dirección';
    // In dark mode tokens.card (#0F1B2D) is too close to tokens.bg
    // (#070E1A) — only 5% lightness apart — and the 8% black drop shadow
    // is invisible on a dark surface. Use the slightly-lighter surface2
    // and add a hairline border so the hero clearly reads as a container.
    final isDark = tokens.isDark;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: isDark ? tokens.surface2 : tokens.card,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: tokens.cardBorder, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Color(isDark ? 0x33000000 : 0x14000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.primaryBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      cliente.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (cliente.notas.trim().isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        cliente.notas.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rutaHeroIcon(
                    icon: Icons.location_on_outlined,
                    iconColor: tokens.primaryBlue,
                    onTap: () {},
                  ),
                  SizedBox(height: 8),
                  _rutaHeroIcon(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: Color(0xFF22C55E),
                    onTap: () => _openRutaWhatsapp(sheetCtx, cliente),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          // IntrinsicHeight stretches both stat cards to the same height
          // (whichever side is taller wins). EN POSESIÓN can grow when
          // there are many product chips; CTA. CORRIENTE stretches to
          // match instead of being shorter.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _rutaHeroStat(
                    label: 'CTA. CORRIENTE',
                    value: _formatRutaMoney(cc),
                    valueColor: ccColor,
                    subtitle: ccSubtitle,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(child: _rutaEnPosesionCard(enLaCalle)),
              ],
            ),
          ),
          SizedBox(height: 18),
          _buildRutaTabs(activeTab, setActiveTab),
        ],
      ),
    );
  }

  Widget _rutaHeroIcon({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
    );
  }

  Widget _rutaHeroStat({
    required String label,
    required String value,
    required Color valueColor,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: tokens.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _rutaEnPosesionCard(Map<int, int> enLaCalle) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EN POSESIÓN',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 6),
          if (enLaCalle.isEmpty)
            Text(
              'Sin productos',
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: enLaCalle.entries.map((e) {
                final productName =
                    _productMapIncludingDeleted[e.key]?.nombre ?? '?';
                final size = _productPackSizes[e.key];
                final displayQty = formatPackQty(e.value, size);
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.cardBorder),
                  ),
                  child: Text(
                    '$displayQty x ${_rutaShortProductName(productName)}',
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRutaTabs(int activeTab, ValueChanged<int> setActiveTab) {
    const labels = ['Venta', 'Datos', 'Historial'];
    // iOS-style segmented control: soft tinted track, white card for the
    // active tab with a subtle lift. Radii nest cleanly inside the 20-px
    // hero (12 outer / 9 inner).
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setActiveTab(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeTab == i ? tokens.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: activeTab == i
                        ? [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: activeTab == i ? tokens.text : tokens.textMuted,
                      fontSize: 13,
                      fontWeight: activeTab == i
                          ? FontWeight.w800
                          : FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRutaDatosCard({
    required Cliente cliente,
    required TextEditingController nombreController,
    required TextEditingController telefonoController,
    required TextEditingController direccionController,
    required TextEditingController notasController,
    required bool readOnly,
  }) {
    final etiquetas = _parseEtiquetas(cliente.etiqueta);
    return Container(
      decoration: _rutaWhiteCardDeco(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rutaFieldBlock(
            'NOMBRE',
            _rutaTextFormField(
              nombreController,
              'Nombre del cliente',
              textCapitalization: TextCapitalization.words,
              readOnly: readOnly,
            ),
          ),
          SizedBox(height: 14),
          _rutaFieldBlock(
            'TELÉFONO',
            _rutaTextFormField(
              telefonoController,
              'Teléfono',
              keyboard: TextInputType.phone,
              readOnly: readOnly,
            ),
          ),
          SizedBox(height: 14),
          _rutaFieldBlock(
            'DIRECCIÓN',
            _rutaTextFormField(
              direccionController,
              'Dirección de entrega',
              textCapitalization: TextCapitalization.words,
              readOnly: readOnly,
            ),
          ),
          SizedBox(height: 14),
          _rutaFieldBlock(
            'NOTAS',
            _rutaTextFormField(
              notasController,
              'Notas internas',
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              readOnly: readOnly,
            ),
          ),
          // Etiquetas — read-only chip row under notas. Editing still
          // happens in the full Clientes detail (this Datos tab is for
          // quick visibility from inside a visita, not a full editor).
          if (etiquetas.isNotEmpty) ...[
            SizedBox(height: 14),
            _rutaFieldBlock(
              'ETIQUETAS',
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: etiquetas.map((e) {
                  final c = _colorForEtiqueta(e);
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e,
                      style: TextStyle(
                        color: c,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rutaFieldBlock(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 7),
        child,
      ],
    );
  }

  Widget _rutaTextFormField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization: textCapitalization,
      readOnly: readOnly,
      onTap: readOnly ? () => blockDemoAction(context) : null,
      style: TextStyle(color: tokens.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tokens.textMuted),
        filled: true,
        fillColor: tokens.surface2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.primaryBlue, width: 1.2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildRutaProductCard({
    required Cliente cliente,
    required String title,
    required String subtitle,
    required List<Producto> products,
    required Map<int, Entrega> entregasForClient,
    required Color qtyColor,
    required Color plusColor,
    required StateSetter setSheetState,
    required bool readOnly,
  }) {
    return Container(
      decoration: _rutaWhiteCardDeco(),
      padding: EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (products.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sin productos',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
            )
          else
            for (var i = 0; i < products.length; i++) ...[
              _buildRutaProductRow(
                cliente: cliente,
                product: products[i],
                entregasForClient: entregasForClient,
                qtyColor: qtyColor,
                plusColor: plusColor,
                setSheetState: setSheetState,
                readOnly: readOnly,
              ),
              if (i < products.length - 1)
                Padding(
                  padding: EdgeInsets.only(left: 60, top: 10, bottom: 10),
                  child: Container(height: 1, color: tokens.cardBorder),
                ),
            ],
        ],
      ),
    );
  }

  Widget _buildRutaProductRow({
    required Cliente cliente,
    required Producto product,
    required Map<int, Entrega> entregasForClient,
    required Color qtyColor,
    required Color plusColor,
    required StateSetter setSheetState,
    required bool readOnly,
  }) {
    final entrega = entregasForClient[product.id];
    final qty = entrega?.entregado ?? 0;
    final clientSelections = _clientePrecioSelections[cliente.id];
    final manualOverride = _overridePrices[cliente.id]?[product.id];
    final price = manualOverride != null && manualOverride > 0
        ? manualOverride
        : _getEffectivePrice(product.id, clientSelections);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _rutaProductTint(product.id).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.local_drink_outlined,
            color: _rutaProductTint(product.id),
            size: 19,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '${_formatRutaMoney(price)} c/u',
                style: TextStyle(color: tokens.textSub, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        _rutaQtyButton(
          icon: Icons.remove_rounded,
          bg: tokens.card,
          fg: tokens.text,
          border: tokens.cardBorder,
          onTap: readOnly
              ? () => blockDemoAction(context)
              : qty > 0
              ? () async {
                  await _updateEntrega(
                    cliente.id,
                    product.id,
                    entregado: qty - 1,
                  );
                  setSheetState(() {});
                }
              : null,
        ),
        SizedBox(width: 10),
        SizedBox(
          width: 24,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: qtyColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        SizedBox(width: 10),
        _rutaQtyButton(
          icon: Icons.add_rounded,
          bg: plusColor,
          fg: Colors.white,
          onTap: readOnly
              ? () => blockDemoAction(context)
              : () async {
                  await _updateEntrega(
                    cliente.id,
                    product.id,
                    entregado: qty + 1,
                  );
                  setSheetState(() {});
                },
        ),
      ],
    );
  }

  Widget _rutaQtyButton({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback? onTap,
    Color? border,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onTap == null ? bg.withValues(alpha: 0.45) : bg,
          borderRadius: BorderRadius.circular(10),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }

  Widget _buildRutaPaymentCard({
    required Cliente cliente,
    required Pago? pago,
    required double totalOwed,
    required TextEditingController montoController,
    required FocusNode panelMontoFocus,
    required VoidCallback markMontoEdited,
    required Future<void> Function() refreshCc,
    required Future<void> Function(String metodo) selectPago,
    required bool readOnly,
  }) {
    return Container(
      decoration: _rutaWhiteCardDeco(),
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Método de pago',
            style: TextStyle(
              color: tokens.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          // Row of equal-flex chips so they always fit on a single line,
          // even when QR is enabled (4 chips total). Each chip uses
          // FittedBox.scaleDown internally to shrink long labels (mainly
          // "Transferencia") rather than wrap to a second row.
          Row(
            children: [
              Expanded(
                child: _rutaPaymentChip(
                  'Efectivo',
                  Icons.payments_outlined,
                  pago?.metodoPago == 'efectivo',
                  readOnly
                      ? () => blockDemoAction(context)
                      : () => selectPago('efectivo'),
                ),
              ),
              SizedBox(width: 6),
              Expanded(
                child: _rutaPaymentChip(
                  // 4-chip layout (QR enabled) needs the shorter label so
                  // every chip reads at full size instead of being
                  // shrunk by FittedBox. With 3 chips there's room for
                  // the full word.
                  _qrEnabled ? 'Transf.' : 'Transferencia',
                  Icons.phone_android,
                  pago?.metodoPago == 'transferencia',
                  readOnly
                      ? () => blockDemoAction(context)
                      : () => selectPago('transferencia'),
                ),
              ),
              if (_qrEnabled) ...[
                SizedBox(width: 6),
                Expanded(
                  child: _rutaPaymentChip('QR', Icons.qr_code, false, () {
                    if (readOnly && blockDemoAction(context)) return;
                    final monto =
                        parseArgNumber(montoController.text)?.toDouble() ??
                        totalOwed;
                    _showMpQrDialog(cliente.id, monto, cliente.nombre);
                  }),
                ),
              ],
              SizedBox(width: 6),
              Expanded(
                child: _rutaPaymentChip(
                  'No pago',
                  Icons.not_interested,
                  pago?.metodoPago == 'no_pago',
                  readOnly
                      ? () => blockDemoAction(context)
                      : () => selectPago('no_pago'),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          TextField(
            controller: montoController,
            focusNode: panelMontoFocus,
            readOnly: readOnly,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onTap: () {
              if (readOnly && blockDemoAction(context)) return;
              markMontoEdited();
              if (montoController.text.isNotEmpty) {
                for (final ms in [50, 100, 200]) {
                  Future.delayed(Duration(milliseconds: ms), () {
                    if (montoController.text.isNotEmpty) {
                      montoController.selection = TextSelection.collapsed(
                        offset: montoController.text.length,
                      );
                    }
                  });
                }
              }
            },
            onChanged: (val) {
              if (readOnly) return;
              markMontoEdited();
              final currentPago = _clientePagos[cliente.id];
              _rememberEditingPagoMethod(cliente.id, currentPago?.metodoPago);
              final action = resolvePaymentEditAction(
                rawMonto: val,
                currentMetodoPago: currentPago?.metodoPago,
                rememberedMetodoPago: _rememberedEditingPagoMethod(cliente.id),
                commit: false,
              );
              if (action.kind == PaymentEditActionKind.save) {
                _setPago(cliente.id, action.metodoPago!, action.monto).then((
                  ok,
                ) {
                  if (ok) refreshCc();
                });
              }
            },
            style: TextStyle(color: tokens.text, fontSize: 15),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: TextStyle(color: tokens.textMuted, fontSize: 15),
              filled: true,
              fillColor: tokens.surface2,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.primaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rutaPaymentChip(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryBlue.withValues(alpha: 0.14)
              : tokens.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? tokens.primaryBlue : tokens.cardBorder,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? tokens.primaryBlue : tokens.textMuted,
                ),
                SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? tokens.primaryBlue : tokens.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRutaHistoryCard({
    required Cliente cliente,
    required StateSetter setSheetState,
    required Future<List<_HistoryEntry>> Function() loadHistory,
    required ValueChanged<List<_HistoryEntry>> setHistoryEntries,
    required List<_HistoryEntry> historyEntries,
    required List<_HistoryEntry> pageEntries,
    required String currentMonthLabel,
    required int historyPage,
    required int totalPages,
    required ValueChanged<int> goHistoryPage,
    required bool readOnly,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if (totalPages <= 1) return;
        final vx = details.velocity.pixelsPerSecond.dx;
        if (vx.abs() < 250) return;
        if (vx > 0 && historyPage > 0) {
          goHistoryPage(-1);
        } else if (vx < 0 && historyPage < totalPages - 1) {
          goHistoryPage(1);
        }
      },
      child: Container(
        decoration: _rutaWhiteCardDeco(),
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  currentMonthLabel.isEmpty ? 'Historial' : currentMonthLabel,
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: readOnly
                      ? () => blockDemoAction(context)
                      : () => _showAddHistoryDialog(
                          cliente,
                          setSheetState,
                          () async => setHistoryEntries(await loadHistory()),
                        ),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: tokens.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (historyEntries.isEmpty)
              Text(
                'Sin historial',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              )
            else
              for (final entry in pageEntries)
                _buildRutaHistoryRow(
                  cliente,
                  entry,
                  setSheetState,
                  loadHistory,
                  setHistoryEntries,
                  readOnly,
                ),
            if (totalPages > 1) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: historyPage > 0 ? () => goHistoryPage(-1) : null,
                    icon: Icon(Icons.chevron_left, color: tokens.textMuted),
                  ),
                  Text(
                    '${historyPage + 1}/$totalPages',
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: historyPage < totalPages - 1
                        ? () => goHistoryPage(1)
                        : null,
                    icon: Icon(Icons.chevron_right, color: tokens.textMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRutaHistoryRow(
    Cliente cliente,
    _HistoryEntry entry,
    StateSetter setSheetState,
    Future<List<_HistoryEntry>> Function() loadHistory,
    ValueChanged<List<_HistoryEntry>> setHistoryEntries,
    bool readOnly,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: readOnly
            ? () => blockDemoAction(context)
            : () => _showEditHistoryForEntry(
                cliente,
                entry,
                setSheetState,
                () async => setHistoryEntries(await loadHistory()),
              ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.cardBorder)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(
                  '${entry.dayAbbr} ${entry.dateLabel}',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  entry.ausente
                      ? 'Ausente'
                      : entry.saltado
                      ? 'Saltado'
                      : entry.noCompro
                      ? 'No compró'
                      : entry.deliveries
                            .map((d) => '${d.entregado} ${d.productName}')
                            .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.text, fontSize: 12),
                ),
              ),
              SizedBox(width: 8),
              Text(
                entry.monto > 0
                    ? _formatRutaMoney(entry.monto)
                    : entry.totalOwed > 0
                    ? _formatRutaMoney(entry.totalOwed)
                    : '',
                style: TextStyle(
                  color: entry.monto > 0 ? tokens.success : tokens.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRutaFooter({
    required double totalOwed,
    required VoidCallback onAbsent,
    required VoidCallback onSkip,
    required VoidCallback onDone,
    required String currentStatus,
  }) {
    final isAbsent = currentStatus == 'absent';
    final isDeferred = currentStatus == 'deferred';
    final isCompleted = currentStatus == 'completed';
    // Bottom inset: respect the system gesture/nav bar so the action
    // buttons don't sit under the Samsung navigation pill. Use
    // viewPadding (the absolute system inset) rather than padding
    // because the latter goes to 0 once a keyboard is up — and we want
    // a consistent buffer regardless of keyboard state.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        border: Border(top: BorderSide(color: tokens.cardBorder, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total venta full-width on its own line.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL VENTA',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                _formatRutaMoney(totalOwed),
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Action buttons on a second line — each chip gets equal flex
          // so the row never feels cramped.
          Row(
            children: [
              Expanded(
                child: _rutaFooterButton(
                  label: 'Ausente',
                  bg: tokens.danger.withValues(alpha: 0.10),
                  fg: tokens.danger,
                  onTap: onAbsent,
                  selected: isAbsent,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _rutaFooterButton(
                  label: 'Saltar',
                  icon: Icons.skip_next_rounded,
                  bg: tokens.card,
                  fg: tokens.text,
                  border: tokens.cardBorder,
                  onTap: onSkip,
                  selected: isDeferred,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _rutaFooterButton(
                  label: 'Listo',
                  icon: Icons.check_rounded,
                  bg: tokens.success,
                  fg: Colors.white,
                  onTap: onDone,
                  bold: true,
                  selected: isCompleted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rutaFooterButton({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    IconData? icon,
    Color? border,
    bool bold = false,
    bool selected = false,
  }) {
    // Material(color: bg) holds the visible fill + rounded shape so the
    // InkWell's splash lands directly on Material's surface. Wrapping the
    // content in a Container with a colored decoration would paint OVER
    // the splash layer and hide the ripple — that was the original bug
    // (bare GestureDetector → no ripple → user perceives tap as inert).
    final effectiveBorderColor = selected ? fg : border;
    final borderWidth = selected ? 2.0 : 1.0;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: effectiveBorderColor == null
            ? BorderSide.none
            : BorderSide(color: effectiveBorderColor, width: borderWidth),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: fg.withValues(alpha: 0.18),
        highlightColor: fg.withValues(alpha: 0.08),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 82, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: fg, size: 17),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: bold ? 15 : 13,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: bold ? 0.4 : 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns true if the client has a monto typed but no payment method selected.
  bool _hasUnconfirmedPayment(int clienteId) {
    final controller = _inlineMontoControllers[clienteId];
    if (controller == null) return false;
    final monto = parseArgNumber(controller.text) ?? 0;
    if (monto <= 0) return false;
    final pago = _clientePagos[clienteId];
    return pago == null; // monto typed but no payment method selected
  }

  void _showPaymentMethodWarning() {
    // Prefer the sheet-scoped messenger when the cliente detail sheet is
    // open so the snackbar surfaces ABOVE the modal. Falls back to root
    // when called from the inline row (sheet not mounted). Mirrors the
    // pattern already used at :1957.
    final messenger =
        _sheetMessengerKey.currentState ?? ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Seleccioná un método de pago antes de confirmar'),
        backgroundColor: tokens.danger,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showMontoWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ingresá el monto antes de confirmar el pago'),
        backgroundColor: tokens.danger,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildViewSegment({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    // iOS-style segmented pill — matches the Venta/Historial tab look.
    // The outer track is surface2; the active pill is the card surface with
    // a soft drop shadow so it appears lifted.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? tokens.card : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? tokens.text : tokens.textMuted,
            ),
            SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? tokens.text : tokens.textMuted,
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Build ---

  Widget _wrapGuided(Widget child) => Stack(
    children: [
      child,
      GuidedTutorialOverlay(
        screen: GuidedScreen.ruta,
        views: _guidedRutaViews(),
      ),
    ],
  );

  Map<GuidedStep, GuidedStepView> _guidedRutaViews() {
    // Resolve the card to spotlight for the "atendé el cliente" step: the
    // tutorial example client if we have it, otherwise the first client. Falls
    // back to a banner (null key) if the list is empty.
    final exId = TutorialController.instance.exampleClientId;
    GlobalKey? clienteKey = exId != null ? _listCardKeys[exId] : null;
    clienteKey ??= _filteredClientes.isNotEmpty
        ? _listCardKeys[_filteredClientes.first.id]
        : null;
    return {
      GuidedStep.rutaIntro: GuidedStepView(
        title: 'Tu ruta del día',
        body:
            'Esta es la lista de clientes de hoy. Si estás en el tutorial, vas a ver un cliente de ejemplo que creamos para practicar.',
      ),
      GuidedStep.rutaMapa: GuidedStepView(
        targetKey: _kRutaToggle,
        title: 'Lista o mapa',
        body:
            'Acá cambiás entre la lista y el mapa para ver el recorrido del día.',
      ),
      GuidedStep.rutaFiltros: GuidedStepView(
        targetKey: _kRutaFilter,
        title: 'Buscar y filtrar',
        body:
            'Con este botón filtrás por estado, frecuencia o etiqueta. Arriba a la izquierda tenés el buscador.',
      ),
      GuidedStep.rutaMarcar: GuidedStepView(
        targetKey: _kRutaFilter,
        title: 'Marcar',
        body: kDemoMode
            ? 'En la app completa podés destacar varios clientes para acciones rápidas.'
            : 'Desde acá también podés marcar varios clientes a la vez para hacer acciones rápidas.',
      ),
      GuidedStep.rutaOrdenar: GuidedStepView(
        targetKey: _kRutaFilter,
        title: 'Ordenar',
        body: kDemoMode
            ? 'En la app completa podés ordenar la ruta por distintos criterios o personalizarla.'
            : 'Y elegís el orden: con «Personalizado» reordenás tus clientes arrastrándolos como quieras.',
      ),
      GuidedStep.rutaCliente: GuidedStepView(
        targetKey: clienteKey,
        title: kDemoMode ? 'Cliente de ejemplo' : 'Atendé el ejemplo',
        body: kDemoMode
            ? 'Tocá el número del cliente para abrir su perfil. Mirá sus datos e historial; cuando vuelvas, terminamos en Más.'
            : 'Tocá el número del cliente para abrir su perfil completo y probar una venta real.',
      ),
      GuidedStep.rutaVender: GuidedStepView(
        bannerAtTop: true,
        title: kDemoMode ? 'Venta' : 'Vendé el producto',
        body: kDemoMode
            ? 'En la app completa cargás los productos vendidos y devueltos para cada cliente.'
            : 'Cargá la cantidad que le vendés al cliente.',
      ),
      GuidedStep.rutaPago: GuidedStepView(
        bannerAtTop: true,
        title: kDemoMode ? 'Pago' : 'Registrá el pago',
        body: kDemoMode
            ? 'Después registrás el pago: efectivo, transferencia, No pagó o QR de Mercado Pago.'
            : 'Elegí cómo te pagó: efectivo, transferencia, etc.',
      ),
      GuidedStep.rutaEstado: GuidedStepView(
        bannerAtTop: true,
        title: kDemoMode ? 'Estado del cliente' : 'Marcá el estado',
        body: kDemoMode
            ? 'Al finalizar una visita real, marcás el estado para que el recorrido avance.'
            : 'Marcá al cliente como entregado, ausente o lo que corresponda.',
      ),
      // rutaVolverInicio spotlights the INICIO bottom-nav button, which lives in
      // the home shell (outside this host), so it's rendered by the inicio host
      // in home_screen.dart, not here.
    };
  }

  @override
  Widget build(BuildContext context) {
    return _wrapGuided(_buildRutaBody());
  }

  Widget _buildRutaBody() {
    if (widget.repartoId == null) {
      return Center(
        child: Text(
          'Seleccioná un reparto para ver la ruta',
          style: TextStyle(color: tokens.textMuted, fontSize: 16),
        ),
      );
    }

    // Mapa mode = fullscreen expanded map. Source of truth is `_mapEnabled`
    // (persisted from the user's manual Lista/Mapa choice), not tutorial state
    // or transient `_mapExpanded`.
    if (_mapExpanded) return _buildExpandedMap();

    return Column(
      children: [
        // Fixed header
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RUTA',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${_filteredClientes.where((c) => _getClientStatus(c.id) != 'pending').length}/${_filteredClientes.length} visitados · ${widget.repartoNombre ?? _dayNameForCurrentDay}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSub,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Container(
                key: _kRutaToggle,
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildViewSegment(
                      label: 'Lista',
                      icon: Icons.list_rounded,
                      active: !_mapExpanded,
                      onTap: () {
                        setState(() {
                          _mapEnabled = false;
                          _mapExpanded = false;
                          _mapPreferenceHydrated = true;
                          _mapFallbackCameraApplied = false;
                        });
                        _db.setMapEnabled(false);
                      },
                    ),
                    _buildViewSegment(
                      label: 'Mapa',
                      icon: Icons.map_outlined,
                      active: _mapExpanded,
                      onTap: () {
                        // Mapa is now the fullscreen interactive map by
                        // default (no more small static preview). Free
                        // the image cache before instantiating GMSMapView
                        // to avoid the historical iOS init crash under
                        // memory pressure.
                        PaintingBinding.instance.imageCache.clear();
                        PaintingBinding.instance.imageCache.clearLiveImages();
                        _geocodeClients();
                        // Auto-focus the next pending cliente so the
                        // mini-card pops up immediately. The camera animate
                        // happens once the map controller is ready
                        // (onMapCreated).
                        final activeId = _activeClienteId;
                        setState(() {
                          _mapEnabled = true;
                          _mapExpanded = true;
                          _mapPreferenceHydrated = true;
                          _mapFallbackCameraApplied = false;
                          _miniCardClienteId = activeId;
                        });
                        _db.setMapEnabled(true);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Legacy "Lista + small static map preview" block removed —
        // unreachable now that the fullscreen map path short-circuits
        // on `_mapEnabled` above.
        // Search bar + QR
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: tokens.textMuted, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: tokens.text, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Buscar cliente o dirección…',
                            hintStyle: TextStyle(
                              color: tokens.textMuted.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _filterClientes();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              color: tokens.textMuted,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                key: _kRutaFilter,
                onTap: _showFilterSheet,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.cardBorder),
                  ),
                  child: Icon(
                    Icons.tune,
                    color: _hasActiveFilters
                        ? tokens.primaryBlue
                        : tokens.textMuted,
                    size: 20,
                  ),
                ),
              ),
              if (widget.selectedDay != null && widget.selectedDay! >= 0) ...[
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _showCrossDayPicker,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tokens.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.cardBorder),
                    ),
                    child: Icon(Icons.add, color: tokens.textMuted, size: 20),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_markingMode) ...[
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: tokens.warn.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _markingMode = false),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app, color: tokens.warn, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Modo marcar activo — tocá clientes para marcarlos. Tocá acá para salir.',
                          style: TextStyle(color: tokens.text, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.close, color: tokens.textSub, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
        ] else
          SizedBox(height: 12),
        // Scrollable client list
        Expanded(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
              return false;
            },
            child: _editMode
                ? ReorderableListView(
                    scrollController: _listScrollController,
                    buildDefaultDragHandles: false,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 4,
                        shadowColor: Colors.black54,
                        child: child,
                      );
                    },
                    onReorder: _onReorderClients,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 300,
                    ),
                    children: _buildClientList(),
                  )
                : ListView(
                    controller: _listScrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 300,
                    ),
                    children: _buildClientList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedMap() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _mapInitialTarget(),
            zoom: _mapInitialZoom(),
          ),
          markers: _clientMarkers,
          polylines: _routePolylines,
          myLocationEnabled: _currentLocation != null,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (c) {
            _mapController = c;
            // If we entered Mapa with a pre-selected cliente (auto-focus on
            // the next pending), animate the camera to its location once the
            // controller is ready. If the simulator has no GPS fix yet, fall
            // back to a client marker or neutral city center instead of
            // leaving the user stuck on "Cargando mapa...".
            final focusId = _miniCardClienteId;
            if (focusId != null) {
              final loc = _geocodedLocations[focusId];
              if (loc != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_mapExpanded) return;
                  _safeAnimateCamera(CameraUpdate.newLatLngZoom(loc, 17));
                });
                _mapFallbackCameraApplied = true;
                return;
              }
            }
            _focusMapOnFallbackIfNeeded();
          },
          onTap: (_) => setState(() => _miniCardClienteId = null),
        ),
        if (_currentLocation == null &&
            _clientMarkers.isEmpty &&
            _geocodingRunning)
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.card.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.cardBorder),
              ),
              child: Text(
                'Ubicando clientes...',
                style: TextStyle(color: tokens.textMuted, fontSize: 13),
              ),
            ),
          ),
        // Back button — returns to Lista mode (Mapa IS the expanded map now).
        Positioned(
          top: 12,
          left: 16,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _mapExpanded = false;
                _mapEnabled = false;
                _mapPreferenceHydrated = true;
                _mapFallbackCameraApplied = false;
                _miniCardClienteId = null;
              });
              _db.setMapEnabled(false);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tokens.card,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back, color: tokens.text, size: 20),
            ),
          ),
        ),
        // FABs — anchored to the top-right so they never shift when the
        // mini-card slides up from the bottom. Same horizontal as the
        // back button, mirrored on the right edge.
        Positioned(
          right: 16,
          top: 12 + MediaQuery.of(context).padding.top,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mapFab(
                icon: Icons.my_location,
                onTap: () {
                  if (_currentLocation != null) {
                    _safeAnimateCamera(
                      CameraUpdate.newLatLngZoom(_currentLocation!, 16),
                    );
                  }
                },
              ),
              SizedBox(height: 12),
              _mapFab(icon: Icons.skip_next, onTap: _goToNextClient),
            ],
          ),
        ),
        // Mini-card — just above navbar/safe area
        if (_miniCardClienteId != null)
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: _buildMiniCard(_miniCardClienteId!),
          ),
      ],
    );
  }

  Widget _mapFab({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: tokens.card,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: tokens.text, size: 24),
      ),
    );
  }

  void _goToNextClient() {
    if (_filteredClientes.isEmpty) return;

    // If no mini-card shown yet, start on the first pending (active) client
    if (_miniCardClienteId == null) {
      final activeId = _activeClienteId;
      if (activeId != null) {
        final loc = _geocodedLocations[activeId];
        if (loc != null) {
          setState(() => _miniCardClienteId = activeId);
          if (_mapController != null) {
            _safeAnimateCamera(CameraUpdate.newLatLngZoom(loc, 17));
          }
          return;
        }
      }
    }

    // Find current index in filtered list
    int currentIdx = -1;
    if (_miniCardClienteId != null) {
      currentIdx = _filteredClientes.indexWhere(
        (c) => c.id == _miniCardClienteId,
      );
    }

    // Start from next index, wrapping around
    final count = _filteredClientes.length;
    for (var i = 1; i <= count; i++) {
      final idx = (currentIdx + i) % count;
      final c = _filteredClientes[idx];
      final loc = _geocodedLocations[c.id];
      if (loc != null) {
        setState(() => _miniCardClienteId = c.id);
        if (_mapController != null) {
          _safeAnimateCamera(CameraUpdate.newLatLngZoom(loc, 17));
        }
        return;
      }
    }
  }

  Widget _buildMiniCard(int clienteId) {
    final cliente = _clientes.where((c) => c.id == clienteId).firstOrNull;
    if (cliente == null) return SizedBox.shrink();
    final idx = _clientes.indexOf(cliente);
    final entregas = _clienteEntregas[clienteId] ?? {};
    final status = _getClientStatus(clienteId);
    final statusColor = _statusCircleColor(status);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor ?? tokens.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ADDRESS (big primary) + close. Name moves below as
            // the secondary label — address is what the sodero is
            // navigating to, so it owns the visual hierarchy.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusColor != null)
                  Container(
                    width: 10,
                    height: 10,
                    margin: EdgeInsets.only(right: 8, top: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                Expanded(
                  child: Text(
                    cliente.direccion.isNotEmpty
                        ? cliente.direccion
                        : 'Sin dirección',
                    style: TextStyle(
                      color: cliente.direccion.isNotEmpty
                          ? tokens.primaryBlue
                          : tokens.text.withValues(alpha: 0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _miniCardClienteId = null),
                  child: Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.close, color: tokens.textMuted, size: 18),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              cliente.nombre,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
            // Quick actions row
            SizedBox(height: 8),
            Row(
              children: [
                if (cliente.telefono.isNotEmpty)
                  _miniCardButton(
                    icon: Icons.chat,
                    color: tokens.success,
                    label: 'WhatsApp',
                    onTap: () => showDemoUpgradeSnack(
                      context,
                      message: 'WhatsApp no esta disponible en la demo.',
                    ),
                  ),
                if (cliente.telefono.isNotEmpty) SizedBox(width: 8),
                if (cliente.direccion.isNotEmpty)
                  _miniCardButton(
                    icon: Icons.navigation,
                    color: tokens.primaryBlue,
                    label: 'Navegar',
                    onTap: () => _openMapsWithAddress(cliente.direccion),
                  ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => _miniCardClienteId = null);
                    _showClientDetail(cliente, idx);
                  },
                  child: Text(
                    'Ver más',
                    style: TextStyle(
                      color: tokens.primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            // Full inline controls: products + payment + status
            _buildActiveInline(cliente, entregas),
          ],
        ),
      ),
    );
  }

  Widget _miniCardButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _statusFilter != 'todos' ||
      _sortMode != 'numero' ||
      _editMode ||
      !_showSemanal ||
      !_showQuincenal ||
      !_showMensual ||
      _selectedEtiquetas.isNotEmpty;

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.bg,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final allTags = _repartoEtiquetas.toList()..sort();

            // Clean pill chip used throughout the sheet. accent overrides
            // the default primaryBlue (used by etiqueta chips which carry
            // their own color).
            Widget pillChip(
              String label,
              bool selected,
              VoidCallback onTap, {
              Color? accentOverride,
            }) {
              final accent = accentOverride ?? tokens.primaryBlue;
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.12)
                        : tokens.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? accent : tokens.cardBorder,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? accent : tokens.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              );
            }

            Widget sectionLabel(String text) => Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                text,
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            );

            BoxDecoration whiteCard() => BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 1),
                ),
              ],
            );

            Widget chipsCard(List<Widget> chips) => Container(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: whiteCard(),
              child: Wrap(spacing: 8, runSpacing: 8, children: chips),
            );

            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 6),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header: title + (optional) Limpiar action
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 6, 12, 12),
                    child: Row(
                      children: [
                        Text(
                          'Filtros',
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Spacer(),
                        if (_hasActiveFilters)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _editMode = false;
                                _shakeController?.stop();
                                _shakeController?.reset();
                              });
                              setSheetState(() {
                                _statusFilter = 'todos';
                                _sortMode = 'numero';
                                _showSemanal = true;
                                _showQuincenal = true;
                                _showMensual = true;
                                _selectedEtiquetas = {};
                              });
                              _filterClientes();
                            },
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: tokens.danger,
                            ),
                            label: Text(
                              'Limpiar',
                              style: TextStyle(
                                color: tokens.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        MediaQuery.of(ctx).padding.bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Estado
                          sectionLabel('ESTADO'),
                          chipsCard([
                            for (final entry in [
                              ['todos', 'Todos'],
                              ['pendientes', 'Pendientes'],
                              ['listos', 'Listos'],
                              ['cobrados', 'Cobrados'],
                              ['deudores', 'Deudores'],
                            ])
                              pillChip(entry[1], _statusFilter == entry[0], () {
                                setSheetState(() => _statusFilter = entry[0]);
                                _filterClientes();
                              }),
                          ]),
                          SizedBox(height: 18),

                          // Ordenar por
                          sectionLabel('ORDENAR POR'),
                          chipsCard([
                            for (final entry in [
                              ['numero', 'Nro. de cliente'],
                              ['cercania', 'Cercanía'],
                              ['personalizado', 'Personalizado'],
                            ])
                              pillChip(
                                entry[1],
                                entry[0] == 'personalizado'
                                    ? _editMode
                                    : _sortMode == entry[0],
                                () {
                                  if (entry[0] == 'personalizado') {
                                    final wasEditMode = _editMode;
                                    setState(() {
                                      _editMode = !_editMode;
                                      if (_editMode) {
                                        _sortMode = 'numero';
                                        _shakeController?.repeat();
                                      } else {
                                        _shakeController?.stop();
                                        _shakeController?.reset();
                                      }
                                    });
                                    setSheetState(() {});
                                    if (wasEditMode) {
                                      _loadData();
                                    } else {
                                      _filterClientes();
                                    }
                                    Navigator.pop(context);
                                  } else {
                                    setState(() {
                                      _editMode = false;
                                      _shakeController?.stop();
                                      _shakeController?.reset();
                                    });
                                    setSheetState(() => _sortMode = entry[0]);
                                    if (entry[0] == 'cercania') {
                                      if (_currentLocation == null) {
                                        _getCurrentLocation().then(
                                          (_) => _fetchDrivingDurations(),
                                        );
                                      } else {
                                        _fetchDrivingDurations();
                                      }
                                    } else {
                                      _filterClientes();
                                    }
                                  }
                                },
                              ),
                          ]),
                          SizedBox(height: 18),

                          // Frecuencia
                          sectionLabel('FRECUENCIA'),
                          chipsCard([
                            pillChip('Semanal', _showSemanal, () {
                              setSheetState(() => _showSemanal = !_showSemanal);
                              _filterClientes();
                            }),
                            pillChip('Quincenal', _showQuincenal, () {
                              setSheetState(
                                () => _showQuincenal = !_showQuincenal,
                              );
                              _filterClientes();
                            }),
                            pillChip('Mensual', _showMensual, () {
                              setSheetState(() => _showMensual = !_showMensual);
                              _filterClientes();
                            }),
                          ]),

                          // Etiquetas (only show if there are tags)
                          if (allTags.isNotEmpty) ...[
                            SizedBox(height: 18),
                            sectionLabel('ETIQUETAS'),
                            chipsCard([
                              for (final tag in allTags)
                                pillChip(
                                  tag,
                                  _selectedEtiquetas.contains(tag),
                                  () {
                                    setSheetState(() {
                                      if (_selectedEtiquetas.contains(tag)) {
                                        _selectedEtiquetas.remove(tag);
                                      } else {
                                        _selectedEtiquetas.add(tag);
                                      }
                                    });
                                    _filterClientes();
                                  },
                                  accentOverride: _colorForEtiqueta(tag),
                                ),
                            ]),
                          ],

                          SizedBox(height: 18),

                          // Marcar entregas (Switch row instead of chip)
                          sectionLabel('MARCAR ENTREGAS'),
                          Container(
                            decoration: whiteCard(),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: tokens.primaryBlue.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.bookmark_added_outlined,
                                    color: tokens.primaryBlue,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Modo destacar',
                                        style: TextStyle(
                                          color: tokens.text,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _markingMode,
                                  onChanged: (v) {
                                    if (!kDemoAllowLiveFlow &&
                                        blockDemoAction(context))
                                      return;
                                    setState(() => _markingMode = v);
                                    Navigator.of(ctx).pop();
                                  },
                                  activeThumbColor: tokens.primaryBlue,
                                  activeTrackColor: tokens.primaryBlue
                                      .withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCrossDayPicker() {
    final repartoId = widget.repartoId;
    final selectedDay = widget.selectedDay;
    if (repartoId == null || selectedDay == null || selectedDay < 0) return;

    final pickerSearchController = TextEditingController();
    final dayOrder = _crossDayOrder(selectedDay);

    Future<Map<int, List<Cliente>>> loadClientes() async {
      final results = await Future.wait(
        dayOrder.map((day) => _db.getClientesForRepartoDay(repartoId, day)),
      );
      return {
        for (var i = 0; i < dayOrder.length; i++) dayOrder[i]: results[i],
      };
    }

    var clientesFuture = loadClientes();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Widget buildSectionTitle(String title) {
              return Padding(
                padding: EdgeInsets.only(top: 18, bottom: 10),
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom +
                    24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.82,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.textMuted.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Agregar cliente de otro día',
                      style: TextStyle(
                        color: tokens.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 14),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: tokens.bg.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Icon(
                              Icons.search,
                              color: tokens.textMuted,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: pickerSearchController,
                              onChanged: (_) => setSheetState(() {}),
                              style: TextStyle(
                                color: tokens.text,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Buscar cliente...',
                                hintStyle: TextStyle(
                                  color: tokens.textMuted.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: FutureBuilder<Map<int, List<Cliente>>>(
                        future: clientesFuture,
                        builder: (ctx, snapshot) {
                          if (snapshot.connectionState !=
                                  ConnectionState.done &&
                              !snapshot.hasData) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: tokens.primaryBlue,
                              ),
                            );
                          }

                          final byDay = snapshot.data ?? {};
                          final query = pickerSearchController.text;
                          final children = <Widget>[];
                          var anyMatches = false;

                          for (final day in dayOrder) {
                            final matches = (byDay[day] ?? <Cliente>[])
                                .where((c) => _matchesClienteSearch(c, query))
                                .toList();
                            if (matches.isEmpty) continue;
                            anyMatches = true;
                            children.add(buildSectionTitle(_allDayNames[day]));
                            for (var i = 0; i < matches.length; i++) {
                              children.add(
                                _buildPickerClienteCard(matches[i], i, () async {
                                  // Target day is implied — the "+" button
                                  // only shows when a recorrido is configured,
                                  // so the destination is always the currently
                                  // selected day. Skip the day picker and go
                                  // straight to "Solo hoy / Siempre". For
                                  // multi-day moves the sodero uses Clientes.
                                  final targetDay = widget.selectedDay;
                                  if (targetDay == null || targetDay < 0) {
                                    return;
                                  }
                                  final scope = await _askCambiarDiaScope(ctx);
                                  if (scope == null) return; // user cancelled
                                  if (scope == 'temp') {
                                    await _db.setClienteTempDay(
                                      matches[i].id,
                                      targetDay,
                                    );
                                  } else {
                                    await _db.moveClienteDayPermanent(
                                      matches[i].id,
                                      targetDay,
                                    );
                                  }
                                  if (!mounted) return;
                                  await _loadData();
                                  if (!mounted) return;
                                  setSheetState(() {
                                    clientesFuture = loadClientes();
                                  });
                                }),
                              );
                            }
                          }

                          if (!anyMatches) {
                            return Center(
                              child: Text(
                                'Sin resultados',
                                style: TextStyle(
                                  color: tokens.textMuted.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }

                          return ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            children: children,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Defer dispose past the dismiss tick — same fix as the cliente
      // edit sheet. Disposing synchronously crashes a TextField that's
      // still being rebuilt during the dismiss animation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pickerSearchController.dispose();
      });
      if (mounted) {
        _clearCrossDaySearchCache();
        _filterClientes();
      } else {
        _clearCrossDaySearchCache();
      }
    });
  }

  Widget _buildPickerClienteCard(
    Cliente cliente,
    int index,
    VoidCallback onTap,
  ) {
    final etiquetas = _parseEtiquetas(cliente.etiqueta);
    final frecLabel =
        cliente.frecuencia[0].toUpperCase() + cliente.frecuencia.substring(1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.cardBorder, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: tokens.textSub,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente.direccion.isNotEmpty
                        ? cliente.direccion
                        : cliente.nombre,
                    style: TextStyle(
                      color: cliente.direccion.isNotEmpty
                          ? tokens.primaryBlue
                          : tokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: cliente.direccion.isNotEmpty
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: cliente.direccion.isNotEmpty
                          ? tokens.primaryBlue.withValues(alpha: 0.4)
                          : null,
                    ),
                  ),
                  SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      if (cliente.direccion.isNotEmpty)
                        Text(
                          cliente.nombre,
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (cliente.direccion.isNotEmpty)
                        Text(
                          '·',
                          style: TextStyle(
                            color: tokens.textMuted.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        frecLabel,
                        style: TextStyle(color: tokens.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    isMoneyNegative(cliente.cuentaCorriente)
                        ? 'Deudor \$${(-cliente.cuentaCorriente).toStringAsFixed(0)}'
                        : 'Al día',
                    style: TextStyle(
                      color: isMoneyNegative(cliente.cuentaCorriente)
                          ? tokens.danger
                          : tokens.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (cliente.notas.isNotEmpty) ...[
                    SizedBox(height: 5),
                    Text(
                      cliente.notas,
                      style: TextStyle(
                        color: tokens.textMuted.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (etiquetas.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: etiquetas
                          .map((e) => _buildTag(e, _colorForEtiqueta(e)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildClientList() {
    final hasCrossDayResults =
        _searchController.text.trim().isNotEmpty &&
        !_editMode &&
        _crossDayMatches.isNotEmpty;
    if (_filteredClientes.isEmpty && _clientes.isEmpty && !hasCrossDayResults) {
      return [
        Padding(
          key: ValueKey('empty'),
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Sin clientes en este reparto',
              style: TextStyle(
                color: tokens.textMuted.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ];
    }
    if (_filteredClientes.isEmpty && !hasCrossDayResults) {
      return [
        Padding(
          key: ValueKey('no_results'),
          padding: EdgeInsets.fromLTRB(32, 52, 32, 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.text.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    size: 28,
                    color: tokens.textMuted,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Sin resultados',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Probá buscando por barrio o calle.',
                  style: TextStyle(color: tokens.textSub, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final clientWidgets = List.generate(_filteredClientes.length, (index) {
      final cliente = _filteredClientes[index];
      final originalIndex = _clientes.indexOf(cliente);
      final status = _getClientStatus(cliente.id);
      final entregasForClient = _clienteEntregas[cliente.id] ?? {};
      final etiquetas = _parseEtiquetas(cliente.etiqueta);

      final expandedId = _expandedClienteId == -1
          ? null
          : (_expandedClienteId ?? _activeClienteId);
      final isActiveClient = expandedId == cliente.id;

      final isMovedHighlight = _movedHighlightId == cliente.id;
      final isMarked = _markedClienteIds.contains(cliente.id);
      Widget cardWidget = Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Stack(
          children: [
            // No compró (skipped) used to render at 55% opacity to feel
            // "dimmed" but the user prefers full opacity — the red badge
            // already signals the status clearly enough.
            Opacity(
              opacity: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: _statusCardColor(status),
                  borderRadius: BorderRadius.circular(14),
                  border: _clienteCardBorder(
                    status: status,
                    isMovedHighlight: isMovedHighlight,
                    isMarked: isMarked,
                  ),
                  boxShadow: isMovedHighlight
                      ? [
                          BoxShadow(
                            color: tokens.primaryBlue.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    // Client header
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _editMode
                          ? null
                          : () async {
                              if (_markingMode) {
                                await _toggleClienteMark(cliente);
                                return;
                              }
                              setState(() {
                                if (isActiveClient) {
                                  _expandedClienteId = -1;
                                } else {
                                  _expandedClienteId = cliente.id;
                                }
                              });
                            },
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              // In Personalizado (edit) mode the number circle is
                              // a shortcut to type a new position. Otherwise it
                              // opens the cliente detail sheet as before.
                              onTap: _editMode
                                  ? () => _showChangePositionDialog(
                                      cliente,
                                      index,
                                    )
                                  : () => _showClientDetail(
                                      cliente,
                                      originalIndex,
                                    ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 0,
                                ),
                                // Status badge gets full opacity in all
                                // states — the colored bg (green / red /
                                // orange / etc.) communicates the status
                                // without needing to dim the cliente.
                                child: Opacity(
                                  opacity: 1.0,
                                  child: _buildStatusBadge(
                                    status,
                                    originalIndex + 1,
                                    editMode: _editMode,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top line: ADDRESS (big primary text).
                                  // Saldo moved down to the name row so the
                                  // top line owns the full width and the
                                  // address can wrap freely.
                                  cliente.direccion.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () => _navigateToClientOnMap(
                                            cliente,
                                            popSheet: false,
                                          ),
                                          child: Text(
                                            cliente.direccion,
                                            softWrap: true,
                                            style: TextStyle(
                                              color: tokens.primaryBlue,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.15,
                                              height: 1.2,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'Sin dirección',
                                          softWrap: true,
                                          style: TextStyle(
                                            color: tokens.text.withValues(
                                              alpha: 0.45,
                                            ),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.15,
                                            height: 1.2,
                                          ),
                                        ),
                                  SizedBox(height: 4),
                                  // Second line: NAME (smaller) + frecuencia
                                  // letter + SALDO. Center-aligned so the
                                  // person icon, name, and frecuencia letter
                                  // line up on the same horizontal axis.
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 13,
                                        color: tokens.textMuted,
                                      ),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          cliente.nombre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: tokens.text,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '·',
                                        style: TextStyle(
                                          color: tokens.textMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        _frecLetter(cliente.frecuencia),
                                        style: TextStyle(
                                          color: tokens.textSub,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                          height: 1.2,
                                        ),
                                      ),
                                      if (_vistaRapidaFields.contains(
                                            'saldo',
                                          ) &&
                                          !isMoneyEffectivelyZero(
                                            cliente.cuentaCorriente,
                                          )) ...[
                                        SizedBox(width: 8),
                                        Text(
                                          _saldoLabel(cliente.cuentaCorriente),
                                          style: TextStyle(
                                            color:
                                                isMoneyNegative(
                                                  cliente.cuentaCorriente,
                                                )
                                                ? tokens.danger
                                                : tokens.success,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  // Order requested by user: notas first,
                                  // etiquetas below.
                                  if (_vistaRapidaFields.contains('notas') &&
                                      cliente.notas.isNotEmpty) ...[
                                    SizedBox(height: 5),
                                    Text(
                                      cliente.notas,
                                      style: TextStyle(
                                        color: tokens.text.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  if (_vistaRapidaFields.contains(
                                        'etiquetas',
                                      ) &&
                                      etiquetas.isNotEmpty) ...[
                                    SizedBox(height: 7),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 5,
                                      children: etiquetas
                                          .map(
                                            (e) => _buildTag(
                                              e,
                                              _colorForEtiqueta(e),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            if (_editMode)
                              ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: tokens.textMuted.withValues(
                                      alpha: 0.7,
                                    ),
                                    size: 18,
                                  ),
                                ),
                              ),
                            // Chevron removed — the bottom pill hint
                            // (rendered below for collapsed cards) is the
                            // only expand affordance now.
                          ],
                        ),
                      ),
                    ),
                    // Bottom pill hint for collapsed cards
                    if (!isActiveClient && !_editMode)
                      Center(
                        child: Container(
                          margin: EdgeInsets.only(bottom: 8),
                          width: 28,
                          height: 3,
                          decoration: BoxDecoration(
                            color: tokens.cardBorder.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    // Active client: show full inline controls + status buttons
                    if (isActiveClient && !_editMode)
                      _buildActiveInline(cliente, entregasForClient),
                  ],
                ),
              ),
            ),
            if (isMarked)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tokens.warn,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tokens.warn.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

      // GlobalKey on the inner card so _scrollToAndHighlightInList can
      // ensureVisible onto the moved cliente after a position change. Kept
      // separate from the outer ValueKey because the latter is consumed by
      // ReorderableListView's reorder tracking — two key types at different
      // widget levels coexist without conflict.
      final cardKey = _listCardKeys.putIfAbsent(cliente.id, () => GlobalKey());
      cardWidget = KeyedSubtree(key: cardKey, child: cardWidget);

      if (_editMode && _shakeController != null) {
        final phase = (index % 3) * 0.33;
        cardWidget = AnimatedBuilder(
          key: ValueKey(cliente.id),
          animation: _shakeController!,
          builder: (context, child) {
            final angle =
                sin((_shakeController!.value + phase) * 2 * pi) * 0.012;
            return Transform.rotate(angle: angle, child: child);
          },
          child: cardWidget,
        );
      } else {
        cardWidget = KeyedSubtree(key: ValueKey(cliente.id), child: cardWidget);
      }

      return cardWidget;
    });

    if (hasCrossDayResults) {
      clientWidgets.add(_buildCrossDayDivider());
      for (var i = 0; i < _crossDayMatches.length; i++) {
        clientWidgets.add(_buildCrossDayResultCard(_crossDayMatches[i], i));
      }
    }

    return clientWidgets;
  }

  Widget _buildCrossDayDivider() {
    return Padding(
      key: ValueKey('otros_dias_divider'),
      padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: tokens.cardBorder.withValues(alpha: 0.5),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Otros días',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: tokens.cardBorder.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrossDayResultCard(_CrossDayClienteMatch match, int index) {
    final cliente = match.cliente;
    final etiquetas = _parseEtiquetas(cliente.etiqueta);
    final frecLabel =
        cliente.frecuencia[0].toUpperCase() + cliente.frecuencia.substring(1);

    return Padding(
      key: ValueKey('cross_day_${cliente.id}_${match.day}'),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showClientDetail(cliente, _clientes.length + index),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBadge('pending', index + 1),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  cliente.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.15,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              if (!isMoneyEffectivelyZero(
                                cliente.cuentaCorriente,
                              ))
                                Text(
                                  _saldoLabel(cliente.cuentaCorriente),
                                  style: TextStyle(
                                    color:
                                        isMoneyNegative(cliente.cuentaCorriente)
                                        ? tokens.danger
                                        : tokens.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: tokens.textMuted,
                                ),
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  cliente.direccion.isNotEmpty
                                      ? cliente.direccion
                                      : 'Sin dirección',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.textSub,
                                    fontSize: 13,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: [
                              _buildTag(frecLabel[0], tokens.textMuted),
                              ...etiquetas.map(
                                (e) => _buildTag(e, _colorForEtiqueta(e)),
                              ),
                            ],
                          ),
                          if (cliente.notas.isNotEmpty) ...[
                            SizedBox(height: 5),
                            Text(
                              cliente.notas,
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 42),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.primaryBlue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tokens.primaryBlue.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    _shortDayName(match.day),
                    style: TextStyle(
                      color: tokens.primaryBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Active client: full inline with product controls + status buttons
  Widget _buildActiveInline(
    Cliente cliente,
    Map<int, Entrega> entregasForClient,
  ) {
    final readOnly = kDemoMode && !kDemoAllowLiveFlow;
    final pago = _clientePagos[cliente.id];
    // Use persistent controller so text isn't wiped on rebuild
    final montoController = _inlineMontoControllers.putIfAbsent(cliente.id, () {
      final totalOwed = _calcTotalOwed(
        entregasForClient,
        clienteId: cliente.id,
      );
      return TextEditingController(
        text: pago != null && pago.monto > 0
            ? pago.monto.toStringAsFixed(0)
            : totalOwed > 0
            ? totalOwed.toStringAsFixed(0)
            : '',
      );
    });

    // Merge favorites (qty 0) into the comprado/devuelto columns.
    // Prefer the cliente's CONFIGURED habituals (cliente_productos with
    // cantidadHabitual > 0); only fall back to the history-derived top-3 when
    // none are configured. This mirrors the client detail sheet, which builds
    // topProductIds the same way — so the inline card and the sheet always
    // show the same habitual products (previously the inline card used only
    // history, so configured-but-no-history clients showed nothing here).
    final configuredHabitualIds =
        (_clienteProducts[cliente.id] ?? <ClienteProducto>[])
            .where((cp) => cp.cantidadHabitual > 0)
            .map((cp) => cp.productoId)
            .toList();
    final topProducts = configuredHabitualIds.isNotEmpty
        ? configuredHabitualIds
        : (_clientTopProducts[cliente.id] ?? <int>[]);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          Divider(color: tokens.cardBorder, height: 1),
          SizedBox(height: 8),
          // Comprado (left) and Devuelto (right) — same product rows, matched 1:1
          ...(() {
            // Unified product list, sorted in carga order (productos.orden).
            // Any habitual product OR any product the cliente has activity
            // for today is shown. The list intentionally does NOT reorder
            // by frequency or quantity — soderos rely on the slot positions
            // staying put so a rapid +1 tap can't land on a sibling that
            // just slid up. The set comes from `topProducts` (habitual top
            // 3 for this cliente) ∪ products with entregado/devuelto > 0
            // today, then sorted by productos.orden. Deleted products only
            // render when they already have today activity, so corrections
            // remain possible without reviving them as habitual options.
            final activityProductIds = entregasForClient.entries
                .where((e) => e.value.entregado > 0 || e.value.devuelto > 0)
                .map((e) => e.key)
                .toSet();
            final candidateIds = <int>{
              ...topProducts.where(_productMap.containsKey),
              ...activityProductIds,
            };
            final allProductIds = _allProductsIncludingDeleted
                .where((p) {
                  if (!candidateIds.contains(p.id)) return false;
                  if (_productMap.containsKey(p.id)) return true;
                  return activityProductIds.contains(p.id);
                })
                .map((p) => p.id)
                .toList();
            if (allProductIds.isEmpty) return <Widget>[];

            return <Widget>[
              // Header row
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          'HABITUAL',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          'COMPRADO',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Text(
                          'DEVUELTO',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4),
              // Product rows
              ...allProductIds.map((pid) {
                final product =
                    _productMap[pid] ?? _productMapIncludingDeleted[pid];
                if (product == null) return SizedBox.shrink();
                final entrega = entregasForClient[pid];
                final qty = entrega?.entregado ?? 0;
                final devQty = entrega?.devuelto ?? 0;
                // "Fav" styling = a habitual placeholder with no activity
                // today. Return-only rows are real activity and must stay
                // visible/editable with the active styling.
                final isFav = qty == 0 && devQty == 0;
                return Padding(
                  padding: EdgeInsets.only(bottom: 4, right: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          _shortenProductName(product.nombre),
                          style: TextStyle(
                            color: isFav ? tokens.textMuted : tokens.textSub,
                            fontSize: 12,
                            fontWeight: isFav
                                ? FontWeight.w500
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        flex: 3,
                        child: _buildSmallQtyControl(
                          qty,
                          onMinus: readOnly
                              ? () => blockDemoAction(context)
                              : () async {
                                  if (qty > 0) {
                                    await _updateEntrega(
                                      cliente.id,
                                      pid,
                                      entregado: qty - 1,
                                    );
                                  }
                                },
                          onPlus: readOnly
                              ? () => blockDemoAction(context)
                              : () async {
                                  await _updateEntrega(
                                    cliente.id,
                                    pid,
                                    entregado: qty + 1,
                                  );
                                },
                          onDirectInput: readOnly
                              ? null
                              : (v) async {
                                  await _updateEntrega(
                                    cliente.id,
                                    pid,
                                    entregado: v,
                                  );
                                },
                        ),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        flex: 3,
                        child: _buildSmallQtyControl(
                          devQty,
                          onMinus: readOnly
                              ? () => blockDemoAction(context)
                              : () async {
                                  if (devQty > 0) {
                                    await _updateEntrega(
                                      cliente.id,
                                      pid,
                                      devuelto: devQty - 1,
                                    );
                                  }
                                },
                          onPlus: readOnly
                              ? () => blockDemoAction(context)
                              : () async {
                                  await _updateEntrega(
                                    cliente.id,
                                    pid,
                                    devuelto: devQty + 1,
                                  );
                                },
                          onDirectInput: readOnly
                              ? null
                              : (v) async {
                                  await _updateEntrega(
                                    cliente.id,
                                    pid,
                                    devuelto: v,
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 6),
            ];
          })(),
          // Pago row — monto input on the LEFT, payment chips on the
          // RIGHT. Keyboard / cursor / autosave logic on the TextField
          // is preserved verbatim from its previous trailing position.
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: montoController,
                    focusNode: _inlineMontoFocusNodeFor(cliente.id),
                    readOnly: readOnly,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onTap: () {
                      if (readOnly && blockDemoAction(context)) return;
                      final ctrl = _inlineMontoControllers[cliente.id];
                      if (ctrl != null && ctrl.text.isNotEmpty) {
                        for (final ms in [50, 100, 200]) {
                          Future.delayed(Duration(milliseconds: ms), () {
                            if (ctrl.text.isNotEmpty) {
                              ctrl.selection = TextSelection.collapsed(
                                offset: ctrl.text.length,
                              );
                            }
                          });
                        }
                      }
                      Future.delayed(Duration(milliseconds: 400), () {
                        final ctx = _inlineMontoFocusNodes[cliente.id]?.context;
                        if (ctx != null && ctx.mounted) {
                          Scrollable.ensureVisible(
                            ctx,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignmentPolicy:
                                ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                          );
                        }
                      });
                    },
                    onChanged: (val) {
                      if (readOnly) return;
                      _manuallyEditedMonto.add(cliente.id);
                      final currentPago = _clientePagos[cliente.id];
                      _rememberEditingPagoMethod(
                        cliente.id,
                        currentPago?.metodoPago,
                      );
                      final action = resolvePaymentEditAction(
                        rawMonto: val,
                        currentMetodoPago: currentPago?.metodoPago,
                        rememberedMetodoPago: _rememberedEditingPagoMethod(
                          cliente.id,
                        ),
                        commit: false,
                      );
                      if (action.kind == PaymentEditActionKind.save) {
                        _setPago(
                          cliente.id,
                          action.metodoPago!,
                          action.monto,
                        ).then((ok) {
                          if (!ok) return;
                        });
                      }
                    },
                    style: TextStyle(color: tokens.text, fontSize: 14),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 14,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      isDense: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: tokens.textMuted.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: tokens.primaryBlue),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              _buildPaymentButton(
                Icons.payments_outlined,
                pago?.metodoPago == 'efectivo',
                () {
                  if (readOnly && blockDemoAction(context)) return;
                  if (_isPagoUndoTap(cliente.id, 'efectivo')) {
                    _removePago(cliente.id);
                    return;
                  }
                  final monto = parseArgNumber(montoController.text) ?? 0;
                  if (monto <= 0) {
                    _showMontoWarning();
                    return;
                  }
                  _setPago(cliente.id, 'efectivo', monto).then((ok) async {
                    if (!ok) return;
                    _provisionalPagoClientes.remove(cliente.id);
                    await _maybeAutoCompleteOnPago(cliente.id);
                  });
                },
                height: 38,
                radius: 8,
                width: 42,
                iconSize: 20,
              ),
              SizedBox(width: 6),
              _buildPaymentButton(
                Icons.phone_android,
                pago?.metodoPago == 'transferencia',
                () {
                  if (readOnly && blockDemoAction(context)) return;
                  if (_isPagoUndoTap(cliente.id, 'transferencia')) {
                    _removePago(cliente.id);
                    return;
                  }
                  final monto = parseArgNumber(montoController.text) ?? 0;
                  if (monto <= 0) {
                    _showMontoWarning();
                    return;
                  }
                  _setPago(cliente.id, 'transferencia', monto).then((ok) async {
                    if (!ok) return;
                    _provisionalPagoClientes.remove(cliente.id);
                    await _maybeAutoCompleteOnPago(cliente.id);
                  });
                },
                height: 38,
                radius: 8,
                width: 42,
                iconSize: 20,
              ),
              SizedBox(width: 6),
              _buildPaymentButton(
                Icons.not_interested,
                pago?.metodoPago == 'no_pago',
                () {
                  if (readOnly && blockDemoAction(context)) return;
                  if (_isPagoUndoTap(cliente.id, 'no_pago')) {
                    _removePago(cliente.id);
                    return;
                  }
                  // P1.3: store the totalOwed as the no_pago monto so the
                  // resumen diario's "today's new deuda" stat
                  // (home_screen.dart:351 sums no_pago.monto into
                  // resumen.cuenta_corriente) is correct. With monto=0,
                  // sueldo bruto/neto came out wrong on credit-extending
                  // days. Detail panel already does this; this brings
                  // inline in line. _calcTotalOwed is now snapshot-first
                  // (P2.1) so the historical price is the truth.
                  final totalOwed = _calcTotalOwed(
                    _clienteEntregas[cliente.id] ?? <int, Entrega>{},
                    clienteId: cliente.id,
                  );
                  montoController.text = totalOwed > 0
                      ? totalOwed.toStringAsFixed(0)
                      : '0';
                  _setPago(cliente.id, 'no_pago', totalOwed).then((ok) async {
                    if (!ok) return;
                    _provisionalPagoClientes.remove(cliente.id);
                    await _maybeAutoCompleteOnPago(cliente.id);
                  });
                },
                height: 38,
                radius: 8,
                width: 42,
                iconSize: 20,
              ),
              if (_qrEnabled) ...[
                SizedBox(width: 6),
                _buildPaymentButton(
                  Icons.qr_code,
                  false,
                  () {
                    if (readOnly && blockDemoAction(context)) return;
                    final monto =
                        parseArgNumber(montoController.text)?.toDouble() ?? 0;
                    _showMpQrDialog(cliente.id, monto, cliente.nombre);
                  },
                  height: 38,
                  radius: 8,
                  width: 42,
                  iconSize: 20,
                ),
              ],
            ],
          ),
          SizedBox(height: 8),
          // Status buttons — centered
          Builder(
            builder: (_) {
              final currentStatus = _getClientStatus(cliente.id);
              final hasStatus = currentStatus != 'pending';
              return Row(
                children: [
                  _buildInlineStatusButton(
                    icon: Icons.close,
                    label: 'No compró',
                    color: tokens.danger,

                    dimmed: hasStatus && currentStatus != 'skipped',
                    onTap: () async {
                      if (readOnly && blockDemoAction(context)) return;
                      if (currentStatus == 'skipped') {
                        unawaited(_setClientStatus(cliente.id, 'pending'));
                        return;
                      }
                      final saved = await _commitInlineMontoEdit(cliente.id);
                      if (!mounted) return;
                      if (!saved) {
                        _showPaymentMethodWarning();
                        return;
                      }
                      if (_hasUnconfirmedPayment(cliente.id)) {
                        _showPaymentMethodWarning();
                        return;
                      }
                      unawaited(_setClientStatus(cliente.id, 'skipped'));
                      _advanceListAfterPaymentComplete(cliente.id);
                    },
                  ),
                  SizedBox(width: 4),
                  _buildInlineStatusButton(
                    icon: Icons.question_mark,
                    label: 'Ausente',
                    color: tokens.warn,

                    dimmed: hasStatus && currentStatus != 'absent',
                    onTap: () async {
                      if (readOnly && blockDemoAction(context)) return;
                      if (currentStatus == 'absent') {
                        unawaited(_setClientStatus(cliente.id, 'pending'));
                        return;
                      }
                      final saved = await _commitInlineMontoEdit(cliente.id);
                      if (!mounted) return;
                      if (!saved) {
                        _showPaymentMethodWarning();
                        return;
                      }
                      if (_hasUnconfirmedPayment(cliente.id)) {
                        _showPaymentMethodWarning();
                        return;
                      }
                      unawaited(_setClientStatus(cliente.id, 'absent'));
                      _advanceListAfterPaymentComplete(cliente.id);
                    },
                  ),
                  SizedBox(width: 4),
                  _buildInlineStatusButton(
                    icon: Icons.remove,
                    label: 'Saltar',
                    color: tokens.textMuted,
                    dimmed: hasStatus && currentStatus != 'deferred',
                    onTap: () async {
                      if (readOnly && blockDemoAction(context)) return;
                      if (currentStatus == 'deferred') {
                        unawaited(_setClientStatus(cliente.id, 'pending'));
                        return;
                      }
                      final confirmed = await _confirmSaltarIfActivity(
                        cliente.id,
                      );
                      if (!mounted || !confirmed) return;
                      unawaited(_setClientStatus(cliente.id, 'deferred'));
                      _advanceListAfterPaymentComplete(cliente.id);
                    },
                  ),
                  SizedBox(width: 4),
                  _buildInlineStatusButton(
                    icon: Icons.check,
                    label: 'Listo',
                    color: tokens.success,

                    dimmed: hasStatus && currentStatus != 'completed',
                    onTap: () async {
                      if (readOnly && blockDemoAction(context)) return;
                      if (currentStatus == 'completed') {
                        unawaited(_setClientStatus(cliente.id, 'pending'));
                        return;
                      }
                      final saved = await _commitInlineMontoEdit(cliente.id);
                      if (!mounted) return;
                      if (!saved) {
                        _showPaymentMethodWarning();
                        return;
                      }
                      if (_hasUnconfirmedPayment(cliente.id)) {
                        _showPaymentMethodWarning();
                        return;
                      }
                      // P3.4 Issue A: drafts must not silently disappear. If
                      // qty edits are pending and no payment chip / no_pago
                      // marker has been chosen, the sodero must explicitly
                      // pick a method — otherwise the next _loadData would
                      // wipe the drafts.
                      if (_draftClienteIds.contains(cliente.id)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Seleccioná un método de pago antes de marcar Listo (Efectivo, Transferencia, o No pagó).',
                            ),
                            backgroundColor: tokens.danger,
                            duration: Duration(seconds: 3),
                          ),
                        );
                        return;
                      }
                      unawaited(_setClientStatus(cliente.id, 'completed'));
                      _advanceListAfterPaymentComplete(cliente.id);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStatusButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool dimmed = false,
  }) {
    final bgColor = dimmed
        ? tokens.cardBorder.withValues(alpha: 0.25)
        : color.withValues(alpha: 0.25);
    final borderClr = dimmed
        ? tokens.cardBorder.withValues(alpha: 0.5)
        : color.withValues(alpha: 0.6);
    final fgColor = dimmed ? tokens.textMuted.withValues(alpha: 0.7) : color;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderClr),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fgColor, size: 13),
              SizedBox(width: 2),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<int?> _showQtyInputDialog(int currentValue) async {
    final controller = TextEditingController(text: '$currentValue');
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cantidad',
          style: TextStyle(
            color: tokens.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            color: tokens.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            filled: true,
            fillColor: tokens.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: Text(
              'OK',
              style: TextStyle(
                color: tokens.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyControl(
    int value, {
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    ValueChanged<int>? onDirectInput,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onMinus,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tokens.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tokens.primaryBlue.withValues(alpha: 0.4),
                ),
              ),
              child: Center(
                child: Text(
                  '-',
                  style: TextStyle(
                    color: tokens.primaryBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onDirectInput != null
                ? () async {
                    final result = await _showQtyInputDialog(value);
                    if (result != null) onDirectInput(result);
                  }
                : null,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onPlus,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tokens.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tokens.primaryBlue.withValues(alpha: 0.4),
                ),
              ),
              child: Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    color: tokens.primaryBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact +/- control for inline order editing
  Widget _buildSmallQtyControl(
    int value, {
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    ValueChanged<int>? onDirectInput,
    double buttonSize = 36,
  }) {
    final fontSize = buttonSize >= 36 ? 22.0 : 18.0;
    final valueFontSize = buttonSize >= 36 ? 16.0 : 13.0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onMinus,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: tokens.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: tokens.primaryBlue.withValues(alpha: 0.4),
                ),
              ),
              child: Center(
                child: Text(
                  '-',
                  style: TextStyle(
                    color: tokens.primaryBlue,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onDirectInput != null
                ? () async {
                    final result = await _showQtyInputDialog(value);
                    if (result != null) onDirectInput(result);
                  }
                : null,
            child: SizedBox(
              width: buttonSize,
              height: buttonSize,
              child: Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onPlus,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: tokens.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: tokens.primaryBlue.withValues(alpha: 0.4),
                ),
              ),
              child: Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    color: tokens.primaryBlue,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(
    IconData icon,
    bool isSelected,
    VoidCallback onTap, {
    double width = 48,
    double height = 44,
    double radius = 10,
    double iconSize = 22,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.primaryBlue.withValues(alpha: 0.25)
              : tokens.textMuted.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isSelected
                ? tokens.primaryBlue
                : tokens.textMuted.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: isSelected ? tokens.primaryBlue : tokens.textSub,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  /// Shorten product name: any word > 4 chars → first 3 chars + "."
  /// Words ≤ 4 chars (numbers, units like "L", "F/C") stay as-is.
  /// e.g. "Botellón 20 L" → "Bot. 20 L", "Soda plástico" → "Soda plá."
  static String _shortenProductName(String name) {
    return name
        .split(' ')
        .map((w) => w.length > 4 ? '${w.substring(0, 3)}.' : w)
        .join(' ');
  }

  /// Set or replace the one-shot manual price for this cliente/product on
  /// the active day. If an entrega for today already carries a stamped
  /// price (draft or committed), rewrite it so the Deudor pill and inline
  /// monto preview reflect the new price immediately.
  Future<void> _applyManualPrice(
    int clienteId,
    int productoId,
    double price,
    void Function(void Function()) setSheetState,
  ) async {
    if (widget.repartoId == null || price <= 0) return;
    final writeKey = '$clienteId:$productoId';
    if (!_manualPriceWritesInFlight.add(writeKey)) return;
    try {
      await _restampEntregaPrice(clienteId, productoId, price);
      _overridePrices.putIfAbsent(clienteId, () => {})[productoId] = price;
      if (mounted) {
        setState(() {});
        setSheetState(() {});
        _refreshInlineMonto(clienteId);
      }
    } finally {
      _manualPriceWritesInFlight.remove(writeKey);
    }
  }

  /// Drop the one-shot price for this cliente/product and re-stamp any
  /// existing entrega with the regular configured price so the monto
  /// falls back to standard pricing in the same frame.
  Future<void> _clearManualPrice(
    int clienteId,
    int productoId,
    void Function(void Function()) setSheetState,
  ) async {
    if (widget.repartoId == null) return;
    final overrides = _overridePrices[clienteId];
    if (overrides == null || !overrides.containsKey(productoId)) return;
    final writeKey = '$clienteId:$productoId';
    if (!_manualPriceWritesInFlight.add(writeKey)) return;
    try {
      final regular = await _db.getEffectivePrice(clienteId, productoId);
      await _restampEntregaPrice(clienteId, productoId, regular);
      overrides.remove(productoId);
      if (overrides.isEmpty) _overridePrices.remove(clienteId);
      if (mounted) {
        setState(() {});
        setSheetState(() {});
        _refreshInlineMonto(clienteId);
      }
    } finally {
      _manualPriceWritesInFlight.remove(writeKey);
    }
  }

  /// Internal: rewrite today's entrega.precioUnitario to `price`. Handles
  /// both the draft (in-memory only) and committed (DB row exists) paths,
  /// so a manual-price toggle takes effect even if the sodero hasn't
  /// landed on a payment chip yet.
  Future<void> _restampEntregaPrice(
    int clienteId,
    int productoId,
    double price,
  ) async {
    if (blockDemoAction(context)) return;
    final entrega = _clienteEntregas[clienteId]?[productoId];
    if (entrega == null || (entrega.entregado <= 0 && entrega.devuelto <= 0)) {
      return; // No entrega yet — override sticks for the next tap of +/-.
    }
    if (_committedToday.contains(clienteId)) {
      _localWriteCount++;
      try {
        final semana = _currentSemana;
        final day = _currentDay;
        await _db.setEntregaWithPrecioUnitarioOverride(
          clienteId,
          widget.repartoId!,
          productoId,
          semana,
          day,
          entrega.entregado,
          entrega.devuelto,
          price,
        );
        final refreshed = await _db.getEntregasForClient(
          clienteId,
          widget.repartoId!,
          semana,
          day,
        );
        _clienteEntregas[clienteId] = {
          for (final e in refreshed) e.productoId: e,
        };
        await _refreshClienteCuentaCorriente(clienteId);
      } finally {
        _localWriteCount--;
      }
    } else {
      // Draft path: mutate in-memory copy so _calcTotalOwed picks up the
      // new snapshot price without ever touching the DB until commit.
      final dayMap = _clienteEntregas.putIfAbsent(clienteId, () => {});
      dayMap[productoId] = entrega.copyWith(precioUnitario: price);
      if (_hasEntregaActivity(clienteId)) {
        _draftClienteIds.add(clienteId);
      } else {
        _draftClienteIds.remove(clienteId);
      }
    }
  }

  /// Show price type selector for a product within a client's detail panel.
  /// Allows selecting which price type applies to this client-product combo.
  // ignore: unused_element
  void _showPriceSelector(
    Producto product,
    int clienteId,
    void Function(void Function()) setSheetState,
  ) {
    if (blockDemoAction(context)) return;
    final prices = _productPrices[product.id] ?? [];
    final currentSelection = _clientePrecioSelections[clienteId]?[product.id];
    final initialOverride = _overridePrices[clienteId]?[product.id];
    final manualCtrl = TextEditingController(
      text: (initialOverride != null && initialOverride > 0)
          ? initialOverride.toStringAsFixed(0)
          : '',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final activeOverride = _overridePrices[clienteId]?[product.id];
            return AlertDialog(
              backgroundColor: tokens.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              titlePadding: EdgeInsets.fromLTRB(16, 14, 16, 0),
              title: Text(
                product.nombre,
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (prices.isEmpty)
                        Text(
                          'No hay precios definidos.\nAgregá precios desde Carga.',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ...prices.map((pp) {
                        final isSelected =
                            activeOverride == null &&
                            (currentSelection == pp.id ||
                                (currentSelection == null &&
                                    pp == prices.first));
                        return GestureDetector(
                          onTap: () async {
                            await _db.setClientePrecioTipo(
                              clienteId,
                              product.id,
                              pp.id,
                            );
                            _clientePrecioSelections.putIfAbsent(
                              clienteId,
                              () => {},
                            )[product.id] = pp.id;
                            // Selecting a regular price type cancels any one-shot
                            // manual price the sodero set for this day. The
                            // existing entrega (if any) is re-stamped with the
                            // newly-chosen tier's price inside _clearManualPrice.
                            if (_overridePrices[clienteId]?.containsKey(
                                  product.id,
                                ) ??
                                false) {
                              await _clearManualPrice(
                                clienteId,
                                product.id,
                                setSheetState,
                              );
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            setState(() {});
                            setSheetState(() {});
                            _refreshInlineMonto(clienteId);
                          },
                          child: Container(
                            margin: EdgeInsets.only(bottom: 6),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tokens.primaryBlue.withValues(alpha: 0.15)
                                  : tokens.surface2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? tokens.primaryBlue
                                    : tokens.cardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    pp.nombre,
                                    style: TextStyle(
                                      color: isSelected
                                          ? tokens.text
                                          : tokens.textSub,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '\$${pp.precio.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? tokens.primaryBlue
                                        : tokens.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isSelected) ...[
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.check_circle,
                                    color: tokens.primaryBlue,
                                    size: 14,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      // --- One-shot manual price ---
                      // Lets the sodero stamp a custom price for THIS day's
                      // entrega only. Doesn't create a price type, doesn't
                      // change the cliente_productos selection — the price
                      // travels on the entrega.precio_unitario snapshot.
                      SizedBox(height: 4),
                      Divider(
                        color: tokens.cardBorder.withValues(alpha: 0.4),
                        height: 16,
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Precio para hoy',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: activeOverride != null
                              ? tokens.primaryBlue.withValues(alpha: 0.15)
                              : tokens.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: activeOverride != null
                                ? tokens.primaryBlue
                                : tokens.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: manualCtrl,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]'),
                                  ),
                                ],
                                style: TextStyle(
                                  color: tokens.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  prefixText: '\$ ',
                                  prefixStyle: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 14,
                                  ),
                                  hintText: 'Ingresá un precio',
                                  hintStyle: TextStyle(
                                    color: tokens.cardBorder,
                                    fontSize: 12,
                                  ),
                                  isDense: true,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (val) async {
                                  final parsed = parseArgNumber(val);
                                  if (parsed == null || parsed <= 0) return;
                                  await _applyManualPrice(
                                    clienteId,
                                    product.id,
                                    parsed.toDouble(),
                                    setSheetState,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              ),
                            ),
                            if (activeOverride != null)
                              GestureDetector(
                                onTap: () async {
                                  await _clearManualPrice(
                                    clienteId,
                                    product.id,
                                    setSheetState,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: tokens.textSub,
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: () async {
                                final parsed = parseArgNumber(manualCtrl.text);
                                if (parsed == null || parsed <= 0) return;
                                await _applyManualPrice(
                                  clienteId,
                                  product.id,
                                  parsed.toDouble(),
                                  setSheetState,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.primaryBlue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Aplicar',
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cerrar',
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      // Same defer-past-dismiss-animation pattern used by the mover-cliente
      // dialog: the parent setSheetState fan-out can rebuild the still-
      // mounted TextField against the controller while the dialog is
      // animating out, so disposing synchronously here would crash with
      // "TextEditingController used after dispose".
      Future.delayed(Duration(milliseconds: 400), manualCtrl.dispose);
    });
  }

  /// Show dialog to edit a historical order using data already loaded in the entry
  Future<void> _showEditHistoryForEntry(
    Cliente cliente,
    _HistoryEntry entry,
    void Function(void Function()) setSheetState,
    Future<void> Function() reloadHistory,
  ) async {
    if (blockDemoAction(context)) return;
    if (widget.repartoId == null) return;
    final allProducts = await _db.getAllProducts(widget.repartoId!);
    if (!mounted) return;

    final date = _weekDayToDate(entry.semana, entry.diaSemana);
    if (date == null) return;

    // Use data already loaded in the entry instead of re-querying DB
    final productQuantities = <int, int>{};
    final productDevueltos = <int, int>{};
    final snapshotPrices = <int, double>{};
    for (final d in entry.deliveries) {
      productQuantities[d.productoId] = d.entregado;
      productDevueltos[d.productoId] = d.devuelto;
      if (d.precioUnitario > 0) {
        snapshotPrices[d.productoId] = d.precioUnitario;
      }
    }

    // Determine estado from entry flags
    String estado = 'listo';
    String paymentMethod = 'efectivo';
    if (entry.noCompro) {
      estado = 'no_compro';
      paymentMethod = entry.monto > 0 ? 'efectivo' : 'no_pago';
    } else if (entry.ausente) {
      estado = 'ausente';
      paymentMethod = entry.monto > 0 ? 'efectivo' : 'no_pago';
    } else if (entry.saltado) {
      estado = 'saltado';
      paymentMethod = 'no_pago';
    } else if (entry.metodoPago != null) {
      paymentMethod = entry.metodoPago!;
    }
    final montoController = TextEditingController(
      text: entry.monto > 0 ? entry.monto.toStringAsFixed(0) : '',
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            double calcTotal() {
              double total = 0;
              for (final e in productQuantities.entries) {
                if (e.value > 0) {
                  // Use snapshotted price if available, otherwise effective price
                  final snapPrice = snapshotPrices[e.key];
                  if (snapPrice != null && snapPrice > 0) {
                    total += snapPrice * e.value;
                  } else {
                    final clientSelections =
                        _clientePrecioSelections[cliente.id];
                    total +=
                        _getEffectivePrice(e.key, clientSelections) * e.value;
                  }
                }
              }
              return total;
            }

            return AlertDialog(
              backgroundColor: tokens.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Editar orden histórica',
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: tokens.cardBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: tokens.primaryBlue,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                              style: TextStyle(
                                color: tokens.text,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Estado',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _historyEstadoChip(
                              'Listo',
                              'listo',
                              tokens.success,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _historyEstadoChip(
                              'No compró',
                              'no_compro',
                              tokens.danger,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _historyEstadoChip(
                              'Ausente',
                              'ausente',
                              tokens.warn,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                        ],
                      ),
                      if (estado == 'listo') ...[
                        SizedBox(height: 16),
                        // Product table header — matches ruta client menu layout
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'PRODUCTOS',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'COMPRADO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'DEVUELTO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ...allProducts.map((product) {
                          final qty = productQuantities[product.id] ?? 0;
                          final dev = productDevueltos[product.id] ?? 0;
                          void syncMonto(void Function() change) {
                            final oldTotal = calcTotal();
                            final currentMonto =
                                parseArgNumber(montoController.text) ?? 0.0;
                            setDialogState(change);
                            if (paymentMethod != 'no_pago' &&
                                (currentMonto == oldTotal ||
                                    montoController.text.isEmpty)) {
                              montoController.text = calcTotal()
                                  .toStringAsFixed(0);
                            }
                          }

                          return Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    _shortenProductName(product.nombre),
                                    style: TextStyle(
                                      color: tokens.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: _buildQtyControl(
                                    qty,
                                    onMinus: () {
                                      if (qty > 0)
                                        syncMonto(
                                          () => productQuantities[product.id] =
                                              qty - 1,
                                        );
                                    },
                                    onPlus: () {
                                      syncMonto(
                                        () => productQuantities[product.id] =
                                            qty + 1,
                                      );
                                    },
                                    onDirectInput: (v) {
                                      syncMonto(
                                        () => productQuantities[product.id] = v,
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  flex: 5,
                                  child: _buildQtyControl(
                                    dev,
                                    onMinus: () {
                                      if (dev > 0)
                                        setDialogState(
                                          () => productDevueltos[product.id] =
                                              dev - 1,
                                        );
                                    },
                                    onPlus: () {
                                      setDialogState(
                                        () => productDevueltos[product.id] =
                                            dev + 1,
                                      );
                                    },
                                    onDirectInput: (v) {
                                      setDialogState(
                                        () => productDevueltos[product.id] = v,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Total: ',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '\$${calcTotal().toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: tokens.primaryBlue,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ], // end if (estado == 'listo')
                      SizedBox(height: 12),
                      Text(
                        'Pago',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _historyPayChip(
                              'Efectivo',
                              'efectivo',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _historyPayChip(
                              'Transfer.',
                              'transferencia',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _historyPayChip(
                              'No pagó',
                              'no_pago',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                        ],
                      ),
                      if (paymentMethod != 'no_pago') ...[
                        SizedBox(height: 12),
                        TextField(
                          controller: montoController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: tokens.text, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Monto pagado',
                            labelStyle: TextStyle(color: tokens.textMuted),
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(color: tokens.textSub),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: tokens.cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: tokens.primaryBlue),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        backgroundColor: tokens.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Eliminar entrada',
                          style: TextStyle(
                            color: tokens.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        content: Text(
                          '¿Eliminar esta entrada del historial?',
                          style: TextStyle(color: tokens.textSub),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: tokens.textMuted),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(
                              'Eliminar',
                              style: TextStyle(color: tokens.danger),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true || !ctx.mounted) return;
                    final uid = AuthService.currentUser?.id;
                    await _db.deleteEntregasForDay(
                      cliente.id,
                      widget.repartoId!,
                      entry.semana,
                      entry.diaSemana,
                      userId: uid,
                    );
                    await _db.deletePago(
                      cliente.id,
                      widget.repartoId!,
                      entry.semana,
                      entry.diaSemana,
                      userId: uid,
                    );
                    // If deleted entry is for today, reset client status and clear inline state
                    if (entry.semana == _currentSemana &&
                        entry.diaSemana == _currentDay) {
                      _clienteStatus.remove(cliente.id);
                      _clienteEntregas.remove(cliente.id);
                      _clientePagos.remove(cliente.id);
                      _inlineMontoControllers.remove(cliente.id)?.dispose();
                      _inlineMontoFocusNodes.remove(cliente.id)?.dispose();
                      _manuallyEditedMonto.remove(cliente.id);
                      _editingPagoMethods.remove(cliente.id);
                      _inlineMontoFocusListenerIds.remove(cliente.id);
                      await _loadData();
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await reloadHistory();
                  },
                  child: Text(
                    'Eliminar',
                    style: TextStyle(color: tokens.danger),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: tokens.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (estado == 'listo') {
                      // Update all products (including zeroed-out ones)
                      final updatedIds = <int>{};
                      final snapshotPrices = <int, double>{
                        for (final d in entry.deliveries)
                          d.productoId: d.precioUnitario,
                      };
                      for (final e in productQuantities.entries) {
                        updatedIds.add(e.key);
                        final entregado = e.value;
                        final devuelto = productDevueltos[e.key] ?? 0;
                        final snap = snapshotPrices[e.key] ?? 0.0;
                        final precio = snap > 0
                            ? snap
                            : await _db.getEffectivePrice(cliente.id, e.key);
                        await _db.setEntrega(
                          cliente.id,
                          widget.repartoId!,
                          e.key,
                          entry.semana,
                          entry.diaSemana,
                          entregado,
                          devuelto,
                          precioUnitario: precio,
                          preserveExistingSnapshot: true,
                        );
                      }
                      // Zero out old entregas that were removed
                      for (final d in entry.deliveries) {
                        if (!updatedIds.contains(d.productoId)) {
                          await _db.setEntrega(
                            cliente.id,
                            widget.repartoId!,
                            d.productoId,
                            entry.semana,
                            entry.diaSemana,
                            0,
                            0,
                          );
                        }
                      }
                    } else {
                      // Clear entregas
                      for (final d in entry.deliveries) {
                        await _db.setEntrega(
                          cliente.id,
                          widget.repartoId!,
                          d.productoId,
                          entry.semana,
                          entry.diaSemana,
                          0,
                          0,
                        );
                      }
                    }
                    // Save pago
                    if (estado != 'listo') {
                      final monto = paymentMethod != 'no_pago'
                          ? (parseArgNumber(montoController.text) ?? 0.0)
                          : 0.0;
                      await _db.setPago(
                        cliente.id,
                        widget.repartoId!,
                        entry.semana,
                        entry.diaSemana,
                        estado,
                        monto,
                      );
                    } else {
                      final total = calcTotal();
                      if (paymentMethod == 'no_pago') {
                        await _db.setPago(
                          cliente.id,
                          widget.repartoId!,
                          entry.semana,
                          entry.diaSemana,
                          'no_pago',
                          total,
                        );
                      } else {
                        final monto =
                            parseArgNumber(montoController.text) ?? total;
                        await _db.setPago(
                          cliente.id,
                          widget.repartoId!,
                          entry.semana,
                          entry.diaSemana,
                          paymentMethod,
                          monto,
                        );
                      }
                    }
                    // P1.1: removed buggy `cuenta_corriente = totalPaid` block.
                    // Each setEntrega/setPago/deletePago/deleteEntregasForDay
                    // above already ran an atomic recalc inside its own DB
                    // transaction (post-Phase-1 contract). The DB-side
                    // recalcCuentaCorrienteForCliente is the only writer of
                    // clientes.cuenta_corriente. Refresh the in-memory cliente
                    // row so the Deudor pill displays the freshly-stored
                    // value.
                    await _refreshClienteCuentaCorriente(cliente.id);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await reloadHistory();
                  },
                  child: Text(
                    'Guardar',
                    style: TextStyle(color: tokens.primaryBlue),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddHistoryDialog(
    Cliente cliente,
    void Function(void Function()) setSheetState,
    Future<void> Function() onSaved,
  ) {
    if (blockDemoAction(context)) return;
    // State for the dialog
    // Default to the most recent occurrence of this reparto's day
    final now = argentinaTime();
    final repartoDayWeekday =
        (_currentDay % 7) +
        1; // _currentDay 0=Mon..6=Sun → weekday 1=Mon..7=Sun
    final daysBack = (now.weekday - repartoDayWeekday) % 7;
    DateTime selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysBack));
    final productQuantities = <int, int>{}; // productoId -> entregado
    final productDevueltos = <int, int>{}; // productoId -> devuelto
    String estado = 'listo';
    String paymentMethod = 'efectivo'; // efectivo, transferencia, no_pago
    final montoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final diaSemana = selectedDate.weekday - 1; // 0=Mon..6=Sun

            // Calculate total from quantities and prices
            double calcTotal() {
              double total = 0;
              final clientSelections = _clientePrecioSelections[cliente.id];
              for (final entry in productQuantities.entries) {
                if (entry.value > 0) {
                  final precio = _getEffectivePrice(
                    entry.key,
                    clientSelections,
                  );
                  total += precio * entry.value;
                }
              }
              return total;
            }

            return AlertDialog(
              backgroundColor: tokens.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Agregar orden histórica',
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: argentinaTime(),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: tokens.primaryBlue,
                                  surface: tokens.card,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: tokens.cardBorder),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: tokens.primaryBlue,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                _allDayNames[diaSemana.clamp(0, 6)],
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Estado',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _historyEstadoChip(
                              'Listo',
                              'listo',
                              tokens.success,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _historyEstadoChip(
                              'No compró',
                              'no_compro',
                              tokens.danger,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                          SizedBox(width: 5),
                          Expanded(
                            child: _historyEstadoChip(
                              'Ausente',
                              'ausente',
                              tokens.warn,
                              estado,
                              (v) => setDialogState(() => estado = v),
                            ),
                          ),
                        ],
                      ),
                      if (estado == 'listo') ...[
                        SizedBox(height: 16),
                        // Product table header — matches ruta client menu layout
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'PRODUCTOS',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'COMPRADO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'DEVUELTO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ..._allProducts.map((product) {
                          final qty = productQuantities[product.id] ?? 0;
                          final dev = productDevueltos[product.id] ?? 0;
                          void syncMonto(void Function() change) {
                            final oldTotal = calcTotal();
                            final currentMonto =
                                parseArgNumber(montoController.text) ?? 0.0;
                            setDialogState(change);
                            if (paymentMethod != 'no_pago' &&
                                (currentMonto == oldTotal ||
                                    montoController.text.isEmpty)) {
                              montoController.text = calcTotal()
                                  .toStringAsFixed(0);
                            }
                          }

                          return Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    _shortenProductName(product.nombre),
                                    style: TextStyle(
                                      color: tokens.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: _buildQtyControl(
                                    qty,
                                    onMinus: () {
                                      if (qty > 0)
                                        syncMonto(
                                          () => productQuantities[product.id] =
                                              qty - 1,
                                        );
                                    },
                                    onPlus: () {
                                      syncMonto(
                                        () => productQuantities[product.id] =
                                            qty + 1,
                                      );
                                    },
                                    onDirectInput: (v) {
                                      syncMonto(
                                        () => productQuantities[product.id] = v,
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  flex: 5,
                                  child: _buildQtyControl(
                                    dev,
                                    onMinus: () {
                                      if (dev > 0)
                                        setDialogState(
                                          () => productDevueltos[product.id] =
                                              dev - 1,
                                        );
                                    },
                                    onPlus: () {
                                      setDialogState(
                                        () => productDevueltos[product.id] =
                                            dev + 1,
                                      );
                                    },
                                    onDirectInput: (v) {
                                      setDialogState(
                                        () => productDevueltos[product.id] = v,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        SizedBox(height: 12),
                        // Total display
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Total: ',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '\$${calcTotal().toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: tokens.primaryBlue,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ], // end if (estado == 'listo')
                      SizedBox(height: 12),
                      // Payment method
                      Text(
                        'Pago',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _historyPayChip(
                              'Efectivo',
                              'efectivo',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _historyPayChip(
                              'Transfer.',
                              'transferencia',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: _historyPayChip(
                              'No pagó',
                              'no_pago',
                              paymentMethod,
                              (v) => setDialogState(() => paymentMethod = v),
                            ),
                          ),
                        ],
                      ),
                      if (paymentMethod != 'no_pago') ...[
                        SizedBox(height: 12),
                        TextField(
                          controller: montoController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          style: TextStyle(color: tokens.text, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Monto pagado',
                            labelStyle: TextStyle(color: tokens.textMuted),
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(color: tokens.textSub),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: tokens.cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: tokens.primaryBlue),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: tokens.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final semana = argentinaWeekString(at: selectedDate);
                    final dia = diaSemana;
                    final repartoId = widget.repartoId;
                    if (repartoId == null) return;

                    // P3.1: refuse to overwrite an existing historial entry.
                    // The user's rule is histories are sacred — they only
                    // change through same-recorrido edits or historial-tap
                    // edits, never via "Add new". Tell the sodero to edit
                    // the existing entry instead.
                    final existingEntregas = await _db.getEntregasForClient(
                      cliente.id,
                      repartoId,
                      semana,
                      dia,
                    );
                    final existingPago = await _db.getPago(
                      cliente.id,
                      repartoId,
                      semana,
                      dia,
                    );
                    final hasExisting =
                        existingEntregas.any(
                          (e) => e.entregado > 0 || e.devuelto > 0,
                        ) ||
                        existingPago != null;
                    if (hasExisting) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ya hay una entrada para esta fecha. Editala desde el historial existente.',
                          ),
                          backgroundColor: tokens.danger,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    if (estado == 'listo') {
                      final clientSelections =
                          _clientePrecioSelections[cliente.id];
                      for (final entry in productQuantities.entries) {
                        final entregado = entry.value;
                        final devuelto = productDevueltos[entry.key] ?? 0;
                        if (entregado > 0 || devuelto > 0) {
                          final precio = _getEffectivePrice(
                            entry.key,
                            clientSelections,
                          );
                          await _db.setEntrega(
                            cliente.id,
                            repartoId,
                            entry.key,
                            semana,
                            dia,
                            entregado,
                            devuelto,
                            precioUnitario: precio,
                          );
                        }
                      }
                    }

                    // Save pago
                    if (estado != 'listo') {
                      final monto = paymentMethod != 'no_pago'
                          ? (parseArgNumber(montoController.text) ?? 0.0)
                          : 0.0;
                      await _db.setPago(
                        cliente.id,
                        repartoId,
                        semana,
                        dia,
                        estado,
                        monto,
                      );
                    } else {
                      final total = calcTotal();
                      if (paymentMethod == 'no_pago') {
                        await _db.setPago(
                          cliente.id,
                          repartoId,
                          semana,
                          dia,
                          'no_pago',
                          total,
                        );
                      } else {
                        final monto =
                            parseArgNumber(montoController.text) ?? total;
                        await _db.setPago(
                          cliente.id,
                          repartoId,
                          semana,
                          dia,
                          paymentMethod,
                          monto,
                        );
                      }
                    }

                    // P1.1: setEntrega/setPago each ran an atomic recalc
                    // inside their own transaction. Just refresh the in-
                    // memory cliente row so Deudor pill updates.
                    await _refreshClienteCuentaCorriente(cliente.id);

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await onSaved();
                  },
                  child: Text(
                    'Guardar',
                    style: TextStyle(color: tokens.primaryBlue),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _historyPayChip(
    String label,
    String value,
    String current,
    void Function(String) onSelect,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryBlue.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? tokens.primaryBlue : tokens.cardBorder,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? tokens.primaryBlue : tokens.textMuted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyEstadoChip(
    String label,
    String value,
    Color color,
    String current,
    void Function(String) onSelect,
  ) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : tokens.cardBorder),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? color : tokens.textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Remote driving-time lookup is intentionally disabled in the demo.
  Future<void> _fetchDrivingDurations() async {
    if (mounted) _filterClientes();
  }

  /// Calculate total owed by a client based on current entregas and product prices.
  /// Uses client's selected price type if set, otherwise first price type, otherwise 0.
  double _calcTotalOwed(Map<int, Entrega> entregasForClient, {int? clienteId}) {
    double total = 0;
    final selections = clienteId != null
        ? _clientePrecioSelections[clienteId]
        : null;
    for (final entry in entregasForClient.entries) {
      final productId = entry.key;
      final entrega = entry.value;
      // P2.1: snapshot-first. A historical entrega's stamped price is the
      // truth — using the current cached price would silently reprice old
      // rows after an admin price update. Drafts have a stamped price (Phase
      // 1's _updateEntrega draft path uses _db.getEffectivePrice at tap
      // time), so this case also satisfies precio_unitario > 0. Legacy
      // zero-snapshot rows fall through to the screen-side cache.
      final overrides = clienteId != null ? _overridePrices[clienteId] : null;
      final overridePrice = overrides?[productId];
      final precio = overridePrice != null && overridePrice > 0
          ? overridePrice
          : entrega.precioUnitario > 0
          ? entrega.precioUnitario
          : _getEffectivePrice(productId, selections);
      if (precio > 0) {
        total += precio * entrega.entregado;
      }
    }
    return total;
  }

  /// Get a short unique label for the selected price type of a product.
  /// Uses first letter of name, or first two if collision, etc.
  // ignore: unused_element
  String _precioShortLabel(int productId, Map<int, int?>? selections) {
    final prices = _productPrices[productId];
    if (prices == null || prices.isEmpty) return '\$';

    // Determine which price type is selected
    final selectedTypeId = selections?[productId];
    ProductoPrecio? selectedPrice;
    if (selectedTypeId != null) {
      selectedPrice = prices.where((pp) => pp.id == selectedTypeId).firstOrNull;
    }
    selectedPrice ??= prices.first;

    // Compute unique abbreviation among all price types for this product
    final allNames = prices.map((pp) => pp.nombre).toList();
    final targetName = selectedPrice.nombre;

    for (int len = 1; len <= targetName.length; len++) {
      final abbr = targetName.substring(0, len).toUpperCase();
      final collisions = allNames
          .where(
            (n) => n.length >= len && n.substring(0, len).toUpperCase() == abbr,
          )
          .length;
      if (collisions <= 1) return abbr;
    }
    return targetName.toUpperCase();
  }

  /// Get effective price for a product given a client's selections map
  double _getEffectivePrice(int productId, Map<int, int?>? selections) {
    // Check client's selected price type
    final selectedTypeId = selections?[productId];
    if (selectedTypeId != null) {
      final prices = _productPrices[productId];
      if (prices != null) {
        final match = prices.where((pp) => pp.id == selectedTypeId).firstOrNull;
        if (match != null) return match.precio;
      }
    }
    // Fallback: first price type for the product
    final prices = _productPrices[productId];
    if (prices != null && prices.isNotEmpty) return prices.first.precio;
    // No price types defined — price is 0
    return 0.0;
  }

  static const List<String> _dayAbbrs = [
    'LUN',
    'MAR',
    'MIÉ',
    'JUE',
    'VIE',
    'SÁB',
  ];

  String _dayAbbr(int dia) {
    return dia >= 0 && dia < _dayAbbrs.length ? _dayAbbrs[dia] : '?';
  }

  /// Convert ISO week string + day index to DateTime
  DateTime? _weekDayToDate(String semana, int dia) {
    final match = RegExp(r'(\d{4})-W(\d{2})').firstMatch(semana);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final week = int.parse(match.group(2)!);
    final jan4 = DateTime(year, 1, 4);
    final monday = jan4
        .subtract(Duration(days: jan4.weekday - 1))
        .add(Duration(days: (week - 1) * 7));
    return monday.add(Duration(days: dia));
  }

  /// Convert ISO week string + day index to "DD/MM" display string
  String _weekDayToDateStr(String semana, int dia) {
    final match = RegExp(r'(\d{4})-W(\d{2})').firstMatch(semana);
    if (match == null) return '??';
    final year = int.parse(match.group(1)!);
    final week = int.parse(match.group(2)!);
    final jan4 = DateTime(year, 1, 4);
    final monday = jan4
        .subtract(Duration(days: jan4.weekday - 1))
        .add(Duration(days: (week - 1) * 7));
    final date = monday.add(Duration(days: dia));
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  // ignore: unused_element
  void _showPhoneOptions(String phone) {
    showDemoUpgradeSnack(
      context,
      message: 'Las acciones de telefono no estan disponibles en la demo.',
    );
  }

  /// Second-step prompt after the sodero picks a destination day: should the
  /// move stick (`'always'`) or just last until midnight (`'temp'`)? Returns
  /// null on dismiss. Shown on top of the day-picker dialog so the existing
  /// dialog stays open behind it — cancelling pops only this layer and the
  /// day picker stays interactive.
  Future<String?> _askCambiarDiaScope(BuildContext parentCtx) {
    return showDialog<String>(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Cuándo aplicar el cambio?',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.today, color: tokens.primaryBlue),
              title: Text(
                'Solo hoy',
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Mañana vuelve a su día habitual',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, 'temp'),
            ),
            ListTile(
              leading: Icon(Icons.event_repeat, color: tokens.primaryBlue),
              title: Text(
                'Siempre',
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'El cliente queda fijo en el nuevo día',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, 'always'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textSub)),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showCambiarDia(
    Cliente cliente,
    void Function(void Function()) setSheetState,
  ) async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    final workDays = await _db.getWorkDays();
    final activeTempDay = await _db.getClienteActiveTempDay(cliente.id);
    if (!mounted) return;
    final availableDays = workDays.isNotEmpty
        ? workDays
        : List.generate(7, (i) => i);
    final effectiveCurrentDay = activeTempDay ?? cliente.diaSemana;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Cambiar de día',
            style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeTempDay != null)
                ListTile(
                  leading: Icon(Icons.restore, color: tokens.primaryBlue),
                  title: Text(
                    'Volver a día habitual',
                    style: TextStyle(
                      color: tokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _allDayNames[cliente.diaSemana],
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                  onTap: () async {
                    final routeNavigator = Navigator.of(context);
                    await _db.clearClienteTempDay(cliente.id);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    routeNavigator.pop();
                    await _loadData();
                    final repartoId = widget.repartoId;
                    if (repartoId == null) return;
                    routeNavigator.push(
                      MaterialPageRoute(
                        builder: (_) => ClientesScreen(
                          repartoId: repartoId,
                          repartoNombre: widget.repartoNombre ?? '',
                          initialSelectedDay: cliente.diaSemana,
                          focusClienteId: cliente.id,
                        ),
                      ),
                    );
                  },
                ),
              ...availableDays.map((i) {
                final isCurrentDay = effectiveCurrentDay == i;
                return ListTile(
                  title: Text(
                    _allDayNames[i],
                    style: TextStyle(
                      color: isCurrentDay ? tokens.primaryBlue : tokens.textSub,
                      fontWeight: isCurrentDay
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isCurrentDay
                      ? Icon(Icons.check, color: tokens.primaryBlue, size: 18)
                      : null,
                  onTap: isCurrentDay
                      ? null
                      : () async {
                          final routeNavigator = Navigator.of(context);
                          final scope = await _askCambiarDiaScope(ctx);
                          if (scope == null) return; // user cancelled
                          if (scope == 'temp') {
                            await _db.setClienteTempDay(cliente.id, i);
                          } else {
                            await _db.moveClienteDayPermanent(cliente.id, i);
                          }
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          routeNavigator.pop();
                          await _loadData();
                          // Send the sodero to the Clientes page for the new
                          // day, with the moved cliente highlighted. Pushed
                          // as a route on top — the active recorrido in Ruta
                          // (under the IndexedStack) keeps running, and its
                          // state, timers, and sync listeners stay intact.
                          final repartoId = widget.repartoId;
                          if (repartoId == null) return;
                          routeNavigator.push(
                            MaterialPageRoute(
                              builder: (_) => ClientesScreen(
                                repartoId: repartoId,
                                repartoNombre: widget.repartoNombre ?? '',
                                initialSelectedDay: i,
                                focusClienteId: cliente.id,
                              ),
                            ),
                          );
                        },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _generateFactura(Cliente cliente) async {
    if (blockDemoAction(context)) return;
    // 1. Check AFIP settings
    final settings = await _db.getSettings();
    if (settings.afipCuit.isEmpty || settings.afipPtoVta == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Configurá tus datos de ARCA en Mi Perfil antes de facturar',
          ),
        ),
      );
      return;
    }

    // 2. Get entregas for this client to build line items
    final semana = _currentSemana;
    final day = _currentDay;
    final entregas = await _db.getEntregasForClient(
      cliente.id,
      widget.repartoId!,
      semana,
      day,
    );

    final items = <Map<String, dynamic>>[];
    double total = 0;

    for (final e in entregas) {
      if (e.entregado <= 0) continue;
      final product = _allProducts
          .where((p) => p.id == e.productoId)
          .firstOrNull;
      if (product == null) continue;
      final price = e.precioUnitario > 0
          ? e.precioUnitario
          : await _db.getEffectivePrice(cliente.id, product.id);
      final subtotal = price * e.entregado;
      items.add({
        'nombre': product.nombre,
        'cantidad': e.entregado,
        'precioUnit': price,
        'subtotal': subtotal,
      });
      total += subtotal;
    }

    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No hay entregas para facturar')));
      return;
    }

    // P0-5 (audit): nunca facturar una línea a $0. Una línea queda en 0
    // cuando la entrega no tiene snapshot Y getEffectivePrice no encontró
    // ningún precio configurado — emitirla generaría una factura AFIP con
    // un importeTotal menor al real, guardada para siempre en facturas.
    // Bloqueamos con los nombres de los productos para que el sodero
    // configure el precio antes de facturar.
    final sinPrecio = unpricedFacturaItems(items);
    if (sinPrecio.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se puede facturar: ${sinPrecio.join(', ')} sin precio '
            'configurado. Configurá el precio del producto antes de facturar.',
          ),
        ),
      );
      return;
    }

    // 3. Show confirmation dialog
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Generar Factura',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cliente: ${cliente.nombre}',
              style: TextStyle(color: tokens.textSub, fontSize: 14),
            ),
            SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item['nombre']} x${item['cantidad']} = \$${(item['subtotal'] as double).toStringAsFixed(2)}',
                  style: TextStyle(color: tokens.textSub, fontSize: 13),
                ),
              ),
            ),
            Divider(color: tokens.textMuted.withValues(alpha: 0.5), height: 16),
            Text(
              'Total: \$${total.toStringAsFixed(2)}',
              style: TextStyle(
                color: tokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Facturar',
              style: TextStyle(
                color: tokens.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 4. Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      // 5. Call AFIP to get last cbteNro and create invoice
      final afip = AfipService(
        cuit: settings.afipCuit,
        production: settings.afipProduction,
      );

      final lastNro = await afip.getLastCbteNro(ptoVta: settings.afipPtoVta);
      final nextNro = lastNro + 1;

      final result = await afip.createInvoice(
        ptoVta: settings.afipPtoVta,
        cbteNro: nextNro,
        importeTotal: total,
        docTipo: 99, // Consumidor Final
        docNro: 0,
      );

      // 6. Generate QR URL
      final qrUrl = afip.generateQrUrl(
        ver: 1,
        fecha: result.fechaCbte,
        cbteTipo: result.cbteTipo,
        ptoVta: result.ptoVta,
        cbteNro: result.cbteNro,
        importeTotal: total,
        cae: result.cae,
      );

      // 7. Generate PDF
      final pdfPath = await InvoicePdfService.generatePdf(
        razonSocial: settings.afipRazonSocial,
        cuit: settings.afipCuit,
        domicilio: settings.afipDomicilio,
        condicionIva: settings.afipCondicionIva,
        ptoVta: result.ptoVta,
        cbteNro: result.cbteNro,
        fecha: result.fechaCbte,
        cae: result.cae,
        caeFchVto: result.caeFchVto,
        importeTotal: total,
        receptorNombre: cliente.nombre,
        receptorDocTipo: 99,
        receptorDocNro: '0',
        items: items,
        qrUrl: qrUrl,
      );

      // 8. Save to database
      final itemsJson = jsonEncode(items);
      await _db.createFactura(
        clienteId: cliente.id,
        repartoId: widget.repartoId!,
        cbteTipo: result.cbteTipo,
        ptoVta: result.ptoVta,
        cbteNro: result.cbteNro,
        fecha: result.fechaCbte,
        importeTotal: total,
        cae: result.cae,
        caeFchVto: result.caeFchVto,
        itemsJson: itemsJson,
        receptorNombre: cliente.nombre,
        receptorDocTipo: 99,
        receptorDocNro: '0',
        pdfPath: pdfPath,
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      // 9. Ask if they want to send it
      _showSendFacturaDialog(cliente, pdfPath, result);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al facturar: $e')));
    }
  }

  void _showSendFacturaDialog(
    Cliente cliente,
    String pdfPath,
    AfipInvoiceResult result,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Factura creada',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Factura C ${result.ptoVta.toString().padLeft(4, '0')}-${result.cbteNro.toString().padLeft(8, '0')} '
          'generada exitosamente.\n\n¿Querés enviarla al cliente?',
          style: TextStyle(color: tokens.textSub),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('No', style: TextStyle(color: tokens.textMuted)),
          ),
          Builder(
            builder: (btnCtx) => TextButton(
              onPressed: () async {
                final rect = _rectFromContext(btnCtx);
                await PlatformFileHelper.instance.sharePdf(
                  pdfPath,
                  sharePositionOrigin: rect,
                );
              },
              child: Text(
                'Compartir',
                style: TextStyle(
                  color: tokens.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _confirmDarDeBaja(Cliente cliente) {
    if (blockDemoAction(context)) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Dar de baja?',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Estás seguro de que querés eliminar a ${cliente.nombre}? Esta acción no se puede deshacer.',
          style: TextStyle(color: tokens.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              await _db.deleteCliente(
                cliente.id,
                userId: AuthService.currentUser?.id,
              );
              SyncService.instance.deleteClienteFromCloud(cliente.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              Navigator.pop(context);
              _loadData();
            },
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
  }
}

class _HistoryEntry {
  final String dateLabel;
  final String dayAbbr;
  final int month; // 1-12, used for grouping by month
  final int year;
  final List<_DeliveryItem> deliveries;
  final double monto; // amount paid
  final double totalOwed; // total owed based on product prices
  final String? metodoPago;
  final bool noCompro;
  final bool ausente;
  final bool saltado;
  final String semana;
  final int diaSemana;

  _HistoryEntry({
    required this.dateLabel,
    required this.dayAbbr,
    required this.month,
    required this.year,
    required this.deliveries,
    required this.monto,
    this.totalOwed = 0,
    this.metodoPago,
    required this.noCompro,
    this.ausente = false,
    this.saltado = false,
    required this.semana,
    required this.diaSemana,
  });

  /// Remaining debt: what they still owe after paying
  double get deuda {
    if (noCompro || ausente || saltado || totalOwed <= 0) return 0;
    if (metodoPago == 'no_pago') return totalOwed;
    final diff = totalOwed - monto;
    return diff > 0 ? diff : 0;
  }
}

class _DeliveryItem {
  final int productoId;
  final String productName;
  final int entregado;
  final int devuelto;
  final double precioUnitario;

  _DeliveryItem({
    required this.productoId,
    required this.productName,
    required this.entregado,
    required this.devuelto,
    this.precioUnitario = 0.0,
  });
}

/// Dialog that generates a Mercado Pago QR code for collecting payment.
/// Creates a checkout preference via the MP API, displays the QR, and polls
/// for payment confirmation.
class _MpQrDialog extends StatefulWidget {
  final String accessToken;
  final double amount;
  final String clienteName;
  final VoidCallback onPaymentConfirmed;

  const _MpQrDialog({
    required this.accessToken,
    required this.amount,
    required this.clienteName,
    required this.onPaymentConfirmed,
  });

  @override
  State<_MpQrDialog> createState() => _MpQrDialogState();
}

class _MpQrDialogState extends State<_MpQrDialog> {
  AppTokens get tokens => AppTokens.of(context);

  String? _initPoint;
  String? _externalRef;
  String? _error;
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _createPreference();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createPreference() async {
    final ref = 'sodapp_${DateTime.now().millisecondsSinceEpoch}';
    final result = await MercadoPagoService.createPreference(
      accessToken: widget.accessToken,
      amount: widget.amount,
      description: 'Reparto - ${widget.clienteName}',
      externalReference: ref,
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _initPoint = result.initPoint;
        _externalRef = ref;
        _loading = false;
      });
      _startPolling();
    } else {
      setState(() {
        _error =
            'No se pudo generar el QR. Verificá tu Access Token en Mi Perfil.';
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      if (_externalRef == null) return;
      final paymentId = await MercadoPagoService.findApprovedPayment(
        accessToken: widget.accessToken,
        externalReference: _externalRef!,
      );
      if (paymentId != null && mounted) {
        _pollTimer?.cancel();
        widget.onPaymentConfirmed();
        Navigator.of(context).pop();
      }
    });
  }

  String _formatAmount(double amount) {
    final isWhole = amount.truncateToDouble() == amount;
    final raw = amount.toStringAsFixed(isWhole ? 0 : 2);
    final parts = raw.split('.');
    final intGrouped = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return parts.length == 2 ? '$intGrouped,${parts[1]}' : intGrouped;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tokens.cardBorder.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header strip
              Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 10, 0),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: tokens.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.qr_code_rounded,
                        color: tokens.primaryBlue,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'COBRO POR QR',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: tokens.textMuted,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              // Amount + client name
              Padding(
                padding: EdgeInsets.fromLTRB(24, 6, 24, 14),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '\$ ',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: _formatAmount(widget.amount),
                              style: TextStyle(
                                color: tokens.text,
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      widget.clienteName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSub,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // QR / loading / error block
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _buildBody(),
              ),
              // Status pill (only when QR is showing)
              if (!_loading && _error == null && _initPoint != null) ...[
                SizedBox(height: 16),
                _statusPill(),
              ],
              // Divider + manual confirm
              if (!_loading && _error == null) ...[
                SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: tokens.cardBorder.withValues(alpha: 0.7),
                ),
                InkWell(
                  onTap: () {
                    _pollTimer?.cancel();
                    widget.onPaymentConfirmed();
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'Marcar como pagado manualmente',
                        style: TextStyle(
                          color: tokens.primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Container(
        height: 244,
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.cardBorder.withValues(alpha: 0.6)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: tokens.primaryBlue,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Generando QR',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Container(
        height: 244,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: tokens.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.danger.withValues(alpha: 0.25)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.danger.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: tokens.danger,
                  size: 26,
                ),
              ),
              SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // QR — always rendered on pure white for scanner reliability.
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.cardBorder.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: QrImageView(
        data: _initPoint!,
        version: QrVersions.auto,
        size: 212,
        backgroundColor: Colors.white,
        // ignore: deprecated_member_use
        foregroundColor: Color(0xFF0F1B2D),
      ),
    );
  }

  Widget _statusPill() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.warn.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: tokens.warn.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.warn,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Esperando pago',
              style: TextStyle(
                color: tokens.warn,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
