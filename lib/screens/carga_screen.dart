import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/app_database.dart';
import '../demo/demo_mode.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../utils/argentina_time.dart';
import '../utils/app_tokens.dart';
import '../utils/pack_format.dart';
import '../utils/parse_number.dart';
import '../widgets/onboarding/tutorial_controller.dart';
import '../widgets/onboarding/guided_tutorial_overlay.dart';

class CargaScreen extends StatefulWidget {
  final int? repartoId;
  final String? repartoNombre;
  final List<int>? workDays;
  // P1.1: when both [selectedDay] and [onSelectedDayChanged] are provided,
  // CargaScreen treats the parent (Home) as the source of truth for which
  // day is being edited. Internal _selectedDay only matters as a fallback
  // when navigated directly without these props. This means Carga and
  // Inicio always agree on the selected day — saving Jueves in Carga
  // updates Inicio's view to Jueves too, instead of leaving it on Lunes.
  final int? selectedDay;
  final ValueChanged<int>? onSelectedDayChanged;
  // P1.1: onCargaChanged now reports which (diaSemana, semana) was
  // edited so the parent reloads the exact day. The previous void-only
  // signature meant Home reloaded whatever day _configSelectedDay
  // happened to be at — usually wrong if the user just edited a different
  // day in Carga.
  final void Function(int diaSemana, String semana)? onCargaChanged;

  const CargaScreen({
    super.key,
    this.repartoId,
    this.repartoNombre,
    this.workDays,
    this.selectedDay,
    this.onSelectedDayChanged,
    this.onCargaChanged,
  });

  @override
  State<CargaScreen> createState() => _CargaScreenState();
}

class _CargaScreenState extends State<CargaScreen> {
  AppTokens get tokens => AppTokens.of(context);

  static const List<String> _allDayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  int _selectedDay = 0;
  // Internal `_selectedDay` is always the source of truth. `widget.selectedDay`
  // is only used as an INITIAL seed (set in `_initWorkDaysAndData`) and to
  // sync on external changes via `didUpdateWidget`. Reason: this screen is
  // pushed via `MaterialPageRoute(builder: (_) => CargaScreen(...))`, which
  // captures the parent's selectedDay at push time. Subsequent parent
  // setState calls don't rebuild the route's child, so relying on
  // `widget.selectedDay` after init would freeze the visible pill on the
  // original day even when the user taps a different one.
  int get _effectiveDay => _selectedDay;

  List<int> _workDays = [0, 1, 2, 3, 4, 5];
  // P1.2: monotonic sequence token. Each _loadData() call captures the
  // current value at start; if a newer load starts before this one
  // returns, the old call discards its results. Without this, rapid
  // day-tapping could leave older results overwriting newer ones.
  int _loadSeq = 0;
  List<Producto> _products = [];
  Map<int, int> _quantities = {};
  Map<int, int> _remanentes = {};
  Map<int, int> _productPackSizes = {};
  int _previousDayRemanenteTotal = 0;
  Map<int, List<ProductoPrecio>> _productPrices = {};
  // Product IDs that have at least one producto_precios row. Drives the $ icon
  // lit/unlit state so it can't drift from product.precio (which a cloud pull
  // race could resurrect after a local price delete).
  Set<int> _productsWithPrices = {};

  final _db = AppDatabase.instance;

  // Guided tutorial spotlight targets.
  final GlobalKey _kAddProduct = GlobalKey();
  final GlobalKey _kProductRow = GlobalKey();
  final GlobalKey _kQty = GlobalKey();
  final GlobalKey _kBack = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initWorkDaysAndData();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => TutorialController.instance.onCargaOpened(),
    );
  }

  Future<void> _initWorkDaysAndData() async {
    final days = widget.workDays ?? await _db.getWorkDays();
    final weekday = argentinaTime().weekday; // 1=Mon, 7=Sun
    final todayIndex = weekday >= 1 && weekday <= 7 ? weekday - 1 : 0;
    if (mounted) {
      setState(() {
        _workDays = days;
        // Seed from parent's selectedDay if provided (initial only), else
        // default to today if it's a work day, else first work day.
        final seed = widget.selectedDay;
        if (seed != null && seed >= 0 && seed < _allDayNames.length) {
          _selectedDay = seed;
        } else {
          _selectedDay = days.contains(todayIndex)
              ? todayIndex
              : (days.isNotEmpty ? days.first : 0);
        }
      });
    }
    await _loadData();
  }

  ({int day, String week}) _previousWorkDayKey(int currentDay) {
    if (_workDays.isEmpty) {
      final prevDay = (currentDay - 1).clamp(0, 6);
      final selectedDate = _dateForCurrentWeekDay(currentDay);
      final wrapsWeek = currentDay == 0;
      return (
        day: prevDay,
        week: argentinaWeekString(
          at: wrapsWeek
              ? selectedDate.subtract(Duration(days: 7))
              : selectedDate,
        ),
      );
    }

    final selectedDate = _dateForCurrentWeekDay(currentDay);
    final position = _workDays.indexOf(currentDay);
    if (position > 0) {
      return (
        day: _workDays[position - 1],
        week: argentinaWeekString(at: selectedDate),
      );
    }
    if (position == 0) {
      return (
        day: _workDays.last,
        week: argentinaWeekString(at: selectedDate.subtract(Duration(days: 7))),
      );
    }

    int? previousInWeek;
    for (final day in _workDays) {
      if (day < currentDay) previousInWeek = day;
    }
    if (previousInWeek != null) {
      return (day: previousInWeek, week: argentinaWeekString(at: selectedDate));
    }
    return (
      day: _workDays.last,
      week: argentinaWeekString(at: selectedDate.subtract(Duration(days: 7))),
    );
  }

  /// P1.4: actual calendar date corresponding to a given day-of-week index
  /// (0 = Lunes ... 6 = Domingo) in the CURRENT ISO week. Used to label
  /// the day tabs so the sodero sees "Jueves 11/03" instead of just
  /// "Jueves" — eliminates the "I thought I was prepping next Thursday
  /// but it wrote to last Thursday" footgun around week boundaries.
  // ignore: unused_element
  DateTime _dateForCurrentWeekDay(int dia) {
    final now = argentinaTime();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: dia));
  }

  // ignore: unused_element
  String _displayDate(DateTime d) => '${d.day} de ${_monthName(d.month)}';

  String _monthName(int month) {
    const names = [
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
    return names[(month - 1).clamp(0, 11)];
  }

  String _formatArMoney(double amount) {
    final isWhole = amount.truncateToDouble() == amount;
    final raw = amount.abs().toStringAsFixed(isWhole ? 0 : 2);
    final parts = raw.split('.');
    final intGrouped = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    final formatted = parts.length == 2
        ? '$intGrouped,${parts[1]}'
        : intGrouped;
    return amount < 0 ? '-\$$formatted' : '\$$formatted';
  }

  Color _productTint(int productId) {
    final palette = [
      tokens.actionRowCargaTint,
      tokens.primaryBlue.withValues(alpha: tokens.isDark ? 0.22 : 0.10),
      tokens.success.withValues(alpha: tokens.isDark ? 0.22 : 0.10),
      tokens.warn.withValues(alpha: tokens.isDark ? 0.22 : 0.12),
      tokens.danger.withValues(alpha: tokens.isDark ? 0.18 : 0.08),
    ];
    return palette[productId.abs() % palette.length];
  }

  double _basePrice(Producto product) {
    // BASE view shows the FIRST custom price the sodero configured for
    // this product (regardless of what they named it). Falls back to the
    // wholesale `product.precio` only when the sodero has not added any
    // custom prices yet.
    final prices = _productPrices[product.id] ?? const <ProductoPrecio>[];
    if (prices.isNotEmpty) return prices.first.precio;
    return product.precio;
  }

  double _visibleUnitPrice(Producto product) => _basePrice(product);

  Future<void> _loadData({int? dayOverride}) async {
    if (widget.repartoId == null) {
      if (mounted) {
        setState(() {
          _products = [];
          _quantities = {};
          _remanentes = {};
          _productPackSizes = {};
          _previousDayRemanenteTotal = 0;
          _productPrices = {};
          _productsWithPrices = {};
        });
      }
      return;
    }
    // P1.2: claim a sequence number BEFORE any await. If a newer load
    // starts mid-flight, this one's results are dropped. Without this,
    // rapid day-taps could finish out of order and put stale day data
    // under the wrong tab.
    final mySeq = ++_loadSeq;
    final capturedRepartoId = widget.repartoId!;
    final capturedDay = dayOverride ?? _effectiveDay;

    // P1.6: one-shot silent retry. The first load right after sign-in
    // can race the cloud-restore transaction (productos still being
    // written when CargaScreen first queries). A single 700ms-spaced
    // retry catches that race without flashing the error snackbar at
    // the user. Only after both attempts fail do we surface the error.
    List<Producto>? products;
    Map<int, ({int cantidad, int remanente})>? cargaData;
    Map<int, ({int cantidad, int remanente})>? previousCargaData;
    Map<int, ({int entregado, int devuelto})>? previousSoldData;
    Map<int, int>? productPackSizes;
    Map<int, List<ProductoPrecio>>? productPrices;
    Set<int>? withPrices;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        products = await _db.getAllProducts(capturedRepartoId);
        final currentWeek = argentinaWeekString();
        cargaData = await _db.getCargaForDayWithRemanente(
          capturedRepartoId,
          capturedDay,
          currentWeek,
        );
        final previousKey = _previousWorkDayKey(capturedDay);
        previousCargaData = await _db.getCargaForDayWithRemanente(
          capturedRepartoId,
          previousKey.day,
          previousKey.week,
        );
        previousSoldData = await _db.getEntregasAggregatedForDay(
          capturedRepartoId,
          previousKey.week,
          previousKey.day,
        );
        productPackSizes = await _db.getProductoPackSizesForReparto(
          capturedRepartoId,
        );
        final allPrecios = await _db.getAllProductoPrecios(capturedRepartoId);
        final priceMap = <int, List<ProductoPrecio>>{};
        for (final pp in allPrecios) {
          priceMap.putIfAbsent(pp.productoId, () => []).add(pp);
        }
        withPrices = {for (final pp in allPrecios) pp.productoId};
        productPrices = priceMap;
        break;
      } catch (e, st) {
        debugPrint(
          '[CargaScreen] _loadData attempt ${attempt + 1} failed: $e\n$st',
        );
        if (mySeq != _loadSeq) return;
        if (attempt == 0) {
          // Quiet retry — most failures here are the post-sign-in
          // restore race and resolve within a fraction of a second.
          await Future.delayed(Duration(milliseconds: 700));
          if (mySeq != _loadSeq) return;
          continue;
        }
        // Both attempts failed. Keep the previously-displayed values
        // intact (no zeros over real data) and surface the message.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo cargar la carga diaria. Tocá un día para reintentar.',
              ),
              backgroundColor: tokens.danger,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    // P1.2: bail if a newer load supersedes us, OR if the user
    // navigated to a different reparto / day during the await chain.
    if (mySeq != _loadSeq) return;
    if (capturedRepartoId != widget.repartoId) return;
    if (dayOverride == null && capturedDay != _effectiveDay) return;
    if (mounted) {
      setState(() {
        _products = products!;
        _quantities = {
          for (final e in cargaData!.entries) e.key: e.value.cantidad,
        };
        _remanentes = {
          for (final e in cargaData.entries) e.key: e.value.remanente,
        };
        _productPackSizes = productPackSizes!;
        // Remanentes del día anterior = carga del último día laboral menos
        // lo vendido ese día. Pack products are counted in packs for display:
        // 6 packs loaded with pack_size=6 and 6 units sold leaves 30 units,
        // shown as 5 packs.
        _previousDayRemanenteTotal = previousCargaData!.entries.fold<int>(0, (
          sum,
          entry,
        ) {
          final sold = previousSoldData![entry.key]?.entregado ?? 0;
          final leftoverUnits = (entry.value.cantidad - sold)
              .clamp(0, entry.value.cantidad)
              .toInt();
          return sum + _packAdjustedQty(entry.key, leftoverUnits);
        });
        _productPrices = productPrices!;
        _productsWithPrices = withPrices!;
      });
    }
  }

  int _packAdjustedQty(int productId, int qty) {
    final size = _productPackSizes[productId];
    // Minimum valid pack size is 2 — anything below means "not a pack"
    // and the quantity passes through unchanged.
    if (size == null || size < 2) return qty;
    return qty ~/ size;
  }

  Future<void> _updateQuantity(int productId, int delta) async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    if (widget.repartoId == null) return;
    final current = _quantities[productId] ?? 0;
    final packSize = _productPackSizes[productId] ?? 1;
    final effectiveDelta = packSize >= 2 ? delta * packSize : delta;
    final newVal = (current + effectiveDelta).clamp(0, 9999);
    if (newVal == current) return;
    // Remanente is independent of cantidad: a sodero may carry leftover
    // bottles even when they load 0 new units today. Clamp only to a
    // non-negative range.
    final rem = (_remanentes[productId] ?? 0).clamp(0, 9999);

    setState(() => _quantities[productId] = newVal);
    final week = argentinaWeekString();
    final day = _effectiveDay;
    await _db.setCantidad(
      widget.repartoId!,
      productId,
      day,
      week,
      newVal,
      remanente: rem,
    );
    // P1.1: pass (day, week) so the parent reloads the exact key we just wrote.
    widget.onCargaChanged?.call(day, week);
    TutorialController.instance.onCargaChanged(day, week);
  }

  Future<void> _setQuantityDirect(
    int productId,
    int value, {
    int? remanente,
  }) async {
    if (!kDemoAllowLiveFlow && blockDemoAction(context)) return;
    if (widget.repartoId == null) return;
    final packSize = _productPackSizes[productId] ?? 1;
    final storedVal = packSize >= 2 ? value * packSize : value;
    final newVal = storedVal.clamp(0, 9999);
    // Remanente is independent of cantidad — clamp to a non-negative
    // range only, never bounded by newVal. A sodero with 15 leftover
    // bottles and 0 new units loaded should still persist remanente=15.
    final rem = (remanente ?? _remanentes[productId] ?? 0).clamp(0, 9999);
    setState(() {
      _quantities[productId] = newVal;
      _remanentes[productId] = rem;
    });
    final week = argentinaWeekString();
    final day = _effectiveDay;
    await _db.setCantidad(
      widget.repartoId!,
      productId,
      day,
      week,
      newVal,
      remanente: rem,
    );
    widget.onCargaChanged?.call(day, week);
    TutorialController.instance.onCargaChanged(day, week);
  }

  Future<({int cantidad, int remanente})?> _showQtyInputDialog(
    int currentValue,
    int currentRemanente,
    int? packSize,
  ) async {
    final isPackProduct = packSize != null && packSize >= 2;
    final displayValue = isPackProduct
        ? currentValue ~/ packSize
        : currentValue;
    final qtyController = TextEditingController(text: '$displayValue');
    final remController = TextEditingController(
      text: currentRemanente > 0 ? '$currentRemanente' : '',
    );
    final remanenteLabel = isPackProduct
        ? 'Remanente (packs del día anterior)'
        : 'Remanente (unidades del día anterior)';
    final cantidadLabel = isPackProduct ? 'Cantidad de packs' : 'Cantidad';
    qtyController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: qtyController.text.length,
    );
    return showDialog<({int cantidad, int remanente})>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isPackProduct ? 'Cantidad de packs' : 'Cantidad',
          style: TextStyle(
            color: tokens.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                cantidadLabel,
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
            ),
            SizedBox(height: 6),
            TextField(
              controller: qtyController,
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
                hintText: '0',
                hintStyle: TextStyle(color: tokens.cardBorder),
                filled: true,
                fillColor: tokens.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) {
                final qty = int.tryParse(qtyController.text) ?? displayValue;
                final rem = int.tryParse(remController.text) ?? 0;
                Navigator.pop(ctx, (cantidad: qty, remanente: rem));
              },
            ),
            SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                remanenteLabel,
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
            ),
            SizedBox(height: 6),
            TextField(
              controller: remController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: tokens.textSub, fontSize: 16),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: tokens.cardBorder),
                filled: true,
                fillColor: tokens.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) {
                final qty = int.tryParse(qtyController.text) ?? displayValue;
                final rem = int.tryParse(remController.text) ?? 0;
                Navigator.pop(ctx, (cantidad: qty, remanente: rem));
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text) ?? displayValue;
              final rem = int.tryParse(remController.text) ?? 0;
              Navigator.pop(ctx, (cantidad: qty, remanente: rem));
            },
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

  @override
  void didUpdateWidget(covariant CargaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repartoId != widget.repartoId) {
      _loadData();
    }
    // Sync work days when they change (e.g. from Configuración)
    if (widget.workDays != null &&
        widget.workDays.toString() != oldWidget.workDays.toString()) {
      final days = widget.workDays!;
      setState(() {
        _workDays = days;
        if (!days.contains(_selectedDay)) {
          _selectedDay = days.isNotEmpty ? days.first : 0;
        }
      });
      _loadData();
    }
    // If the parent flipped selectedDay externally (e.g., Inicio's day
    // picker), sync our internal day and reload. Tapping a pill inside
    // Carga itself uses internal state only — this branch is for the
    // external-control case.
    if (widget.selectedDay != null &&
        widget.selectedDay != oldWidget.selectedDay &&
        widget.selectedDay != _selectedDay) {
      setState(() => _selectedDay = widget.selectedDay!);
      _loadData();
    }
  }

  Widget _wrapGuided(Widget child) {
    return Stack(
      children: [
        child,
        GuidedTutorialOverlay(
          screen: GuidedScreen.carga,
          views: _guidedViews(),
        ),
      ],
    );
  }

  Map<GuidedStep, GuidedStepView> _guidedViews() => {
    GuidedStep.addProduct: GuidedStepView(
      targetKey: _kAddProduct,
      title: kDemoMode ? 'Productos' : 'Creá tu primer producto',
      body: kDemoMode
          ? 'El demo ya trae productos cargados. En la app completa podés crear los tuyos.'
          : 'Tocá «Agregar otro producto» y ponele un nombre (ej. Botellón 20L).',
    ),
    GuidedStep.setPrices: GuidedStepView(
      targetKey: _kProductRow,
      title: kDemoMode ? 'Precios' : 'Ponele precios',
      body: kDemoMode
          ? 'En cada producto configurás costo mayorista y precios de venta. En el demo solo se muestran como ejemplo.'
          : 'Tocá tu producto: cargá el costo mayorista (lo que te cuesta) y un precio de venta (a cuánto lo vendés).',
    ),
    GuidedStep.addQty: GuidedStepView(
      targetKey: _kQty,
      title: kDemoMode ? 'Cantidad cargada' : 'Sumá al camión',
      body: kDemoMode
          ? 'En la app completa registrás cuánta mercadería sube al camión y el remanente.'
          : 'Con + / − (o tocando el número) cargá cuántos subís hoy al camión.',
    ),
    GuidedStep.cargaBack: GuidedStepView(
      targetKey: _kBack,
      title: '¡Listo!',
      body: 'Tocá la flecha para volver y seguir.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (widget.repartoId == null) {
      return _scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Seleccioná un reparto para ver la carga',
              style: TextStyle(color: tokens.textMuted, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return _wrapGuided(
      _scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildHeaderCard(),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'PRODUCTOS',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(height: 12),
            Expanded(child: _buildProductList()),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: KeyedSubtree(
                key: _kAddProduct,
                child: _buildAddProductButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scaffold({required Widget body}) {
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.card,
        surfaceTintColor: tokens.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: tokens.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        shape: Border(bottom: BorderSide(color: tokens.cardBorder, width: 1)),
        leading: IconButton(
          key: _kBack,
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: tokens.text),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'CARGA',
          style: TextStyle(
            color: tokens.text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _buildHeaderCard() {
    final totalProducts = _quantities.entries.fold<int>(
      0,
      (sum, entry) => sum + _packAdjustedQty(entry.key, entry.value),
    );
    final totalRemanentes = _previousDayRemanenteTotal;
    final totalValue = _products.fold<double>(
      0,
      (sum, product) =>
          sum + _visibleUnitPrice(product) * (_quantities[product.id] ?? 0),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.22 : 0.06),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date title + subtitle removed per Phase 3 — AppBar already
          // shows "CARGA", and the day pills below identify the selected
          // day visually. This frees vertical space for the product list.
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _workDays.length; index++) ...[
                    _buildDayPill(_workDays[index]),
                    if (index != _workDays.length - 1) SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    label: 'PRODUCTOS',
                    value: '$totalProducts',
                    subtitle: 'cargados hoy',
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    label: 'REMANENTES',
                    value: '$totalRemanentes',
                    subtitle: 'del día anterior',
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    label: 'VALOR',
                    value: _formatArMoney(totalValue),
                    subtitle: 'si vendés todo',
                    valueColor: tokens.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayPill(int day) {
    final isSelected = _effectiveDay == day;
    return GestureDetector(
      onTap: () {
        // Always update internal state — that's our source of truth. The
        // parent callback (if any) is just a notification so it can sync
        // its own state without us depending on it for our UI.
        setState(() => _selectedDay = day);
        widget.onSelectedDayChanged?.call(day);
        _loadData(dayOverride: day);
      },
      child: Container(
        width: 64,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? tokens.primaryBlue : tokens.card,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: tokens.cardBorder),
        ),
        child: Text(
          _allDayNames[day].substring(0, day == 2 ? 3 : 3).toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : tokens.text,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required String subtitle,
    Color? valueColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 5),
        // Fixed-height value cell. FittedBox.scaleDown preserves aspect
        // ratio, so a wide value (BASE total ≫ MAYORISTA total) would
        // shrink BOTH width and height — making the tile shorter in BASE
        // than in MAYORISTA. Locking the cell height keeps every stat
        // tile (and thus the header card) the same size in both modes.
        SizedBox(
          height: 28,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: valueColor ?? tokens.text,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.textSub, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildProductList() {
    if (_products.isEmpty) {
      return Center(
        child: Text(
          'No hay productos',
          style: TextStyle(color: tokens.textMuted, fontSize: 14),
        ),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: tokens.isDark ? 0.22 : 0.05,
                ),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var index = 0; index < _products.length; index++) ...[
                _buildProductRow(_products[index]),
                if (index != _products.length - 1)
                  Padding(
                    padding: EdgeInsets.only(left: 60),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: tokens.cardBorder,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductRow(Producto product) {
    final qty = _quantities[product.id] ?? 0;
    final rem = _remanentes[product.id] ?? 0;
    final unitPrice = _visibleUnitPrice(product);
    final hasPrice = _productsWithPrices.contains(product.id);

    return InkWell(
      key: product.id == TutorialController.instance.newProductId
          ? _kProductRow
          : null,
      onTap: () => _showPricePanel(product),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _productTint(product.id),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.water_drop_outlined,
                color: tokens.primaryBlue,
                size: 22,
              ),
            ),
            SizedBox(width: 10),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${_formatArMoney(unitPrice)} c/u',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tokens.textSub, fontSize: 12),
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(
                        Icons.sell_outlined,
                        color: hasPrice
                            ? tokens.primaryBlue
                            : tokens.textMuted.withValues(alpha: 0.65),
                        size: 13,
                      ),
                    ],
                  ),
                  if (rem > 0) ...[
                    SizedBox(height: 2),
                    Text(
                      _productPackSizes[product.id] != null &&
                              _productPackSizes[product.id]! >= 2
                          ? 'Remanente: $rem packs'
                          : 'Remanente: $rem unidades',
                      style: TextStyle(color: tokens.textMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8),
            Row(
              key: product.id == TutorialController.instance.newProductId
                  ? _kQty
                  : null,
              mainAxisSize: MainAxisSize.min,
              children: [
                _quantityButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _updateQuantity(product.id, -1),
                ),
                GestureDetector(
                  onTap: () async {
                    final v = await _showQtyInputDialog(
                      qty,
                      rem,
                      _productPackSizes[product.id],
                    );
                    if (v != null) {
                      await _setQuantityDirect(
                        product.id,
                        v.cantidad,
                        remanente: v.remanente,
                      );
                    }
                  },
                  child: SizedBox(
                    width: 52,
                    child: Center(
                      child: Text(
                        formatPackQty(qty, _productPackSizes[product.id]),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          color: tokens.primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                _quantityButton(
                  icon: Icons.add_rounded,
                  isPrimary: true,
                  onTap: () => _updateQuantity(product.id, 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary ? tokens.primaryBlue : tokens.card,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary ? null : Border.all(color: tokens.cardBorder),
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.white : tokens.text,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAddProductButton() {
    return Material(
      color: tokens.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _showAddProductDialog,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: tokens.text, size: 20),
              SizedBox(width: 8),
              Text(
                'Agregar otro producto',
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddProductDialog() {
    if (blockDemoAction(context)) return;
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Nuevo producto',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: tokens.text),
          decoration: InputDecoration(
            labelText: 'Nombre *',
            labelStyle: TextStyle(color: tokens.textMuted),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final newId = await _db.createProduct(widget.repartoId!, name);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              // Set newProductId BEFORE reloading so the rebuilt product row
              // picks up the _kProductRow/_kQty tutorial keys.
              TutorialController.instance.onProductCreated(newId);
              await _loadData();
            },
            child: Text('Agregar', style: TextStyle(color: tokens.primaryBlue)),
          ),
        ],
      ),
    );
  }

  Future<int?> _askPackSize(int initial) async {
    final ctrl = TextEditingController(text: initial.toString());
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unidades por pack',
          style: TextStyle(
            color: tokens.text,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: tokens.text, fontSize: 18),
              decoration: InputDecoration(
                hintText: '2',
                hintStyle: TextStyle(
                  color: tokens.textMuted.withValues(alpha: 0.7),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: tokens.primaryBlue.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: tokens.primaryBlue),
                ),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Mínimo 2',
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: Text('Guardar', style: TextStyle(color: tokens.primaryBlue)),
          ),
        ],
      ),
    );
  }

  void _showPricePanel(Producto product) async {
    if (blockDemoAction(context)) return;
    int? currentPackSize = await _db.getProductoPackSize(product.id);
    if (!mounted) return;
    // Cache the data future ACROSS rebuilds. Without this, the FutureBuilder
    // received a brand new Future on every setSheetState — which made it
    // re-subscribe and dispose+rebuild its descendants (the Switch, etc.).
    // The visible symptom was: tapping the pack Switch ON worked, but
    // tapping it again to turn OFF appeared to do nothing — the Switch
    // got remounted mid-toggle and the new value was discarded.
    Future<(List<Producto>, List<ProductoPrecio>)> dataFuture = (() async {
      final prods = await _db.getAllProducts(product.repartoId!);
      final prices = await _db.getProductoPrecios(product.id);
      return (prods, prices);
    })();
    void refreshData(void Function(void Function()) setSheetState) {
      // Call this after a price edit / add / delete to re-fetch the data.
      setSheetState(() {
        dataFuture = (() async {
          final prods = await _db.getAllProducts(product.repartoId!);
          final prices = await _db.getProductoPrecios(product.id);
          return (prods, prices);
        })();
      });
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
            return FutureBuilder<(List<Producto>, List<ProductoPrecio>)>(
              future: dataFuture,
              builder: (context, snapshot) {
                var currentProduct = snapshot.data != null
                    ? snapshot.data!.$1
                              .where((p) => p.id == product.id)
                              .firstOrNull ??
                          product
                    : product;
                final prices = snapshot.data?.$2 ?? [];
                Widget sectionHeader(IconData icon, String label) => Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Row(
                    children: [
                      Icon(icon, size: 14, color: tokens.textMuted),
                      SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                );

                BoxDecoration sectionCardDeco() => BoxDecoration(
                  color: tokens.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: tokens.isDark ? 0.18 : 0.05,
                      ),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                );

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.of(context).viewInsets.bottom +
                        MediaQuery.of(context).padding.bottom +
                        20,
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
                      SizedBox(height: 16),
                      Text(
                        currentProduct.nombre,
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      sectionHeader(Icons.warehouse_outlined, 'MAYORISTA'),
                      GestureDetector(
                        onTap: () {
                          final ctrl = TextEditingController(
                            text: currentProduct.precio > 0
                                ? currentProduct.precio.toStringAsFixed(
                                    currentProduct.precio.truncateToDouble() ==
                                            currentProduct.precio
                                        ? 0
                                        : 2,
                                  )
                                : '',
                          );
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: tokens.surface2,
                              title: Text(
                                'Costo mayorista',
                                style: TextStyle(
                                  color: tokens.text,
                                  fontSize: 16,
                                ),
                              ),
                              content: TextField(
                                controller: ctrl,
                                autofocus: true,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: TextStyle(
                                  color: tokens.text,
                                  fontSize: 18,
                                ),
                                decoration: InputDecoration(
                                  prefixText: '\$ ',
                                  prefixStyle: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 18,
                                  ),
                                  hintText: 'sin definir',
                                  hintStyle: TextStyle(
                                    color: tokens.textMuted.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: tokens.primaryBlue.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: tokens.primaryBlue,
                                    ),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      color: tokens.text.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final text = ctrl.text.trim();
                                    final parsed = text.isEmpty
                                        ? null
                                        : parseArgNumber(text);
                                    final value = parsed == null || parsed <= 0
                                        ? 0.0
                                        : parsed;
                                    await _db.updateProductPrecio(
                                      currentProduct.id,
                                      value,
                                    );
                                    TutorialController.instance
                                        .onPriceChanged();
                                    setSheetState(
                                      () => currentProduct = currentProduct
                                          .copyWith(precio: value),
                                    );
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    refreshData(setSheetState);
                                    await _loadData();
                                  },
                                  child: Text(
                                    'Guardar',
                                    style: TextStyle(color: tokens.primaryBlue),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: sectionCardDeco(),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentProduct.precio <= 0
                                      ? 'sin definir'
                                      : _formatArMoney(currentProduct.precio),
                                  style: TextStyle(
                                    color: currentProduct.precio <= 0
                                        ? tokens.warn
                                        : tokens.primaryBlue,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.edit,
                                color: tokens.textMuted.withValues(alpha: 0.7),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14),
                        decoration: sectionCardDeco(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Es pack',
                                    style: TextStyle(
                                      color: tokens.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Switch(
                                  // OFF = not a pack (effectively 1 item
                                  // per unit, no aggregation adjustment).
                                  // ON  = pack with a minimum of 2 units.
                                  value:
                                      currentPackSize != null &&
                                      currentPackSize! >= 2,
                                  onChanged: (v) async {
                                    if (!v) {
                                      await _db.setProductoPackSize(
                                        currentProduct.id,
                                        null,
                                      );
                                      setSheetState(
                                        () => currentPackSize = null,
                                      );
                                    } else {
                                      // Default to 2 — the minimum valid
                                      // pack size when toggling ON.
                                      await _db.setProductoPackSize(
                                        currentProduct.id,
                                        2,
                                      );
                                      setSheetState(() => currentPackSize = 2);
                                    }
                                    await _loadData();
                                  },
                                  activeThumbColor: tokens.primaryBlue,
                                ),
                              ],
                            ),
                            if (currentPackSize != null &&
                                currentPackSize! >= 2) ...[
                              SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    'Unidades por pack',
                                    style: TextStyle(
                                      color: tokens.textSub,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Spacer(),
                                  InkWell(
                                    onTap: () async {
                                      final newSize = await _askPackSize(
                                        currentPackSize!,
                                      );
                                      // Minimum valid pack size is 2.
                                      // Anything less keeps the existing
                                      // value (no-op).
                                      if (newSize == null || newSize < 2) {
                                        return;
                                      }
                                      await _db.setProductoPackSize(
                                        currentProduct.id,
                                        newSize,
                                      );
                                      setSheetState(
                                        () => currentPackSize = newSize,
                                      );
                                      await _loadData();
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.primaryBlue.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$currentPackSize',
                                        style: TextStyle(
                                          color: tokens.primaryBlue,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 18),
                      sectionHeader(Icons.sell_outlined, 'VENTA'),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: sectionCardDeco(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (prices.isEmpty)
                              Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'No hay precios definidos',
                                  style: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ...prices.map(
                              (pp) => Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tokens.cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pp.nombre,
                                        style: TextStyle(
                                          color: tokens.text,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatArMoney(pp.precio),
                                      style: TextStyle(
                                        color: tokens.primaryBlue,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => _editPriceType(
                                        currentProduct,
                                        pp,
                                        setSheetState,
                                        () => refreshData(setSheetState),
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        color: tokens.textMuted,
                                        size: 18,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: tokens.card,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title: Text(
                                              'Eliminar precio',
                                              style: TextStyle(
                                                color: tokens.text,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            content: Text(
                                              '¿Eliminar "${pp.nombre}" (${_formatArMoney(pp.precio)})?',
                                              style: TextStyle(
                                                color: tokens.text,
                                                fontSize: 14,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: Text(
                                                  'Cancelar',
                                                  style: TextStyle(
                                                    color: tokens.text
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text(
                                                  'Eliminar',
                                                  style: TextStyle(
                                                    color: tokens.danger,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed != true) return;
                                        final uid = AuthService.currentUser?.id;
                                        if (uid == null) return;
                                        await _db.deleteProductoPrecio(
                                          pp.id,
                                          uid,
                                        );
                                        SyncService.instance.scheduleSyncSoon();
                                        refreshData(setSheetState);
                                        await _loadData();
                                      },
                                      child: Icon(
                                        Icons.close,
                                        color: tokens.textMuted.withValues(
                                          alpha: 0.7,
                                        ),
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () => _addPriceType(
                                  currentProduct,
                                  setSheetState,
                                  () => refreshData(setSheetState),
                                ),
                                icon: Icon(Icons.add, size: 18),
                                label: Text(
                                  'Agregar precio a vender',
                                  style: TextStyle(fontSize: 14),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: tokens.primaryBlue,
                                  side: BorderSide(
                                    color: tokens.primaryBlue.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _confirmDeleteProduct(currentProduct),
                          icon: Icon(Icons.delete_outline, size: 18),
                          label: Text(
                            'Eliminar producto',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.danger,
                            side: BorderSide(
                              color: tokens.danger.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
      },
    );
  }

  void _addPriceType(
    Producto product,
    void Function(void Function()) setSheetState,
    void Function() refreshData,
  ) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    // Get unique price type names from all products
    final allPrecios = await _db.getAllProductoPrecios(widget.repartoId!);
    final existingNames =
        allPrecios
            .map((p) => p.nombre.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Nuevo tipo de precio',
            style: TextStyle(
              color: tokens.text,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick-select chips for existing names
              if (existingNames.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nombres existentes',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: existingNames.map((name) {
                    final selected = nameController.text.trim() == name;
                    return GestureDetector(
                      onTap: () {
                        nameController.text = name;
                        setDialogState(() {});
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? tokens.primaryBlue.withValues(alpha: 0.2)
                              : tokens.text.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? tokens.primaryBlue
                                : tokens.text.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: selected
                                ? tokens.primaryBlue
                                : tokens.textSub,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 14),
              ],
              TextField(
                controller: nameController,
                autofocus: existingNames.isEmpty,
                style: TextStyle(color: tokens.text),
                onChanged: (_) => setDialogState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nombre (ej. Base, Descuento)',
                  labelStyle: TextStyle(color: tokens.textMuted),
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
              SizedBox(height: 12),
              TextField(
                controller: priceController,
                autofocus: existingNames.isNotEmpty,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: TextStyle(color: tokens.text),
                decoration: InputDecoration(
                  labelText: 'Precio *',
                  labelStyle: TextStyle(color: tokens.textMuted),
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: tokens.textMuted),
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
                final price = parseArgNumber(priceController.text);
                if (price == null || price <= 0) return;
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await _db.createProductoPrecio(
                  widget.repartoId!,
                  product.id,
                  name,
                  price,
                );
                TutorialController.instance.onPriceChanged();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                refreshData();
                await _loadData();
              },
              child: Text(
                'Agregar',
                style: TextStyle(color: tokens.primaryBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(Producto product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar producto',
          style: TextStyle(color: tokens.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Eliminar "${product.nombre}"? Se borrarán sus precios y asignaciones a clientes. Las entregas pasadas no se verán afectadas.',
          style: TextStyle(color: tokens.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              // Phase 11a: pass userId so deleteProduct creates a
              // pending_deletions tombstone in the same transaction as
              // the local cascade. If the immediate cloud cascade
              // below fails (offline / network), the tombstone makes
              // sure the delete still propagates on the next sync.
              final userId = AuthService.currentUser?.id;
              await _db.deleteProduct(product.id, userId: userId);
              SyncService.instance.deleteProductFromCloud(product.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx); // close dialog
              if (!mounted) return;
              Navigator.pop(context); // close price sheet
              await _loadData();
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

  void _editPriceType(
    Producto product,
    ProductoPrecio pp,
    void Function(void Function()) setSheetState,
    void Function() refreshData,
  ) {
    final nameController = TextEditingController(text: pp.nombre);
    final priceController = TextEditingController(
      text: pp.precio.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Editar precio',
          style: TextStyle(
            color: tokens.text,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: tokens.text),
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: TextStyle(color: tokens.textMuted),
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
            SizedBox(height: 12),
            TextField(
              controller: priceController,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: TextStyle(color: tokens.text),
              decoration: InputDecoration(
                labelText: 'Precio',
                labelStyle: TextStyle(color: tokens.textMuted),
                prefixText: '\$ ',
                prefixStyle: TextStyle(color: tokens.textMuted),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: tokens.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final price = parseArgNumber(priceController.text) ?? 0.0;
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await _db.updateProductoPrecioName(pp.id, name);
              }
              await _db.updateProductoPrecioValue(pp.id, price);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              refreshData();
              await _loadData();
            },
            child: Text('Guardar', style: TextStyle(color: tokens.primaryBlue)),
          ),
        ],
      ),
    );
  }
}
