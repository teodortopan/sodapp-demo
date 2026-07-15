import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../utils/argentina_time.dart';
import 'demo_mode.dart';

class _DemoProductSeed {
  final String name;
  final double salePrice;
  final double wholesalePrice;
  final int? packSize;
  final int loaded;
  final int remanente;

  const _DemoProductSeed({
    required this.name,
    required this.salePrice,
    required this.wholesalePrice,
    this.packSize,
    required this.loaded,
    required this.remanente,
  });
}

class _DemoClientSeed {
  final String name;
  final String address;
  final String phone;
  final String etiqueta;
  final String notas;
  final double lat;
  final double lng;

  const _DemoClientSeed({
    required this.name,
    required this.address,
    required this.phone,
    required this.etiqueta,
    required this.notas,
    required this.lat,
    required this.lng,
  });
}

const _products = [
  _DemoProductSeed(
    name: 'Soda 12L',
    salePrice: 3200,
    wholesalePrice: 2100,
    loaded: 42,
    remanente: 5,
  ),
  _DemoProductSeed(
    name: 'Agua 20L',
    salePrice: 3600,
    wholesalePrice: 2400,
    loaded: 28,
    remanente: 4,
  ),
  _DemoProductSeed(
    name: 'Sifones pack x6',
    salePrice: 7200,
    wholesalePrice: 4800,
    packSize: 6,
    loaded: 10,
    remanente: 1,
  ),
  _DemoProductSeed(
    name: 'Dispenser',
    salePrice: 9500,
    wholesalePrice: 6500,
    loaded: 6,
    remanente: 0,
  ),
];

const _clients = [
  _DemoClientSeed(
    name: 'Almacen Demo Norte',
    address: 'Calle Ejemplo 101, Ciudad Demo',
    phone: '+54 9 11 0000-0101',
    etiqueta: 'Comercio',
    notas: 'Entregar por la entrada lateral.',
    lat: -34.58791,
    lng: -58.42413,
  ),
  _DemoClientSeed(
    name: 'Familia Ejemplo',
    address: 'Pasaje Muestra 202, Ciudad Demo',
    phone: '+54 9 11 0000-0102',
    etiqueta: 'Casa',
    notas: 'Prefiere pago por transferencia.',
    lat: -34.58957,
    lng: -58.42358,
  ),
  _DemoClientSeed(
    name: 'Oficinas Horizonte',
    address: 'Avenida Demo 303, Ciudad Demo',
    phone: '+54 9 11 0000-0103',
    etiqueta: 'Empresa',
    notas: 'Pedir recepcion en PB.',
    lat: -34.59068,
    lng: -58.42813,
  ),
  _DemoClientSeed(
    name: 'Cafe La Muestra',
    address: 'Calle Portfolio 404, Ciudad Demo',
    phone: '+54 9 11 0000-0104',
    etiqueta: 'Gastronomia',
    notas: 'Horario ideal: antes de las 11.',
    lat: -34.58722,
    lng: -58.43003,
  ),
  _DemoClientSeed(
    name: 'Edificio Modelo',
    address: 'Pasaje Ficticio 505, Ciudad Demo',
    phone: '+54 9 11 0000-0105',
    etiqueta: 'Consorcio',
    notas: 'Dejar aviso al encargado.',
    lat: -34.58842,
    lng: -58.41076,
  ),
  _DemoClientSeed(
    name: 'Kiosco Punto Demo',
    address: 'Avenida Ejemplo 606, Ciudad Demo',
    phone: '+54 9 11 0000-0106',
    etiqueta: 'Comercio',
    notas: 'Compra todas las semanas.',
    lat: -34.58077,
    lng: -58.42192,
  ),
  _DemoClientSeed(
    name: 'Loft Muestra',
    address: 'Calle Sin Datos 707, Ciudad Demo',
    phone: '+54 9 11 0000-0107',
    etiqueta: 'Casa',
    notas: 'Cliente nuevo de ejemplo.',
    lat: -34.58835,
    lng: -58.43094,
  ),
  _DemoClientSeed(
    name: 'Estudio Portfolio',
    address: 'Pasaje Modelo 808, Ciudad Demo',
    phone: '+54 9 11 0000-0108',
    etiqueta: 'Empresa',
    notas: 'Deuda simulada para mostrar historial.',
    lat: -34.59337,
    lng: -58.42979,
  ),
];

Future<void> seedDemoData() async {
  if (!kDemoMode) return;

  final db = AppDatabase.instance;
  await db.ensureUserSettingsRow();
  await _clearDemoTables(db);

  final now = argentinaTime();
  final todayDay = now.weekday - 1;
  final todayWeek = argentinaWeekString(at: now);
  final lastWeekDate = now.subtract(const Duration(days: 7));
  final lastWeek = argentinaWeekString(at: lastWeekDate);
  final lastMonthDate = now.subtract(const Duration(days: 28));
  final lastMonthWeek = argentinaWeekString(at: lastMonthDate);

  final repartoId = await db.createReparto(
    'Reparto Demo - Palermo',
    kDemoUserId,
  );
  await db.restoreCuentaFromCloud(
    userId: kDemoUserId,
    email: kDemoEmail,
    nombre: 'Soderia La Plaza',
    telefono: '+54 9 11 0000-0100',
  );

  await db.customStatement(
    "UPDATE user_settings SET "
    "work_days = '0,1,2,3,4,5', "
    "qr_enabled = 1, "
    "map_enabled = 0, "
    "auto_listo_on_pago = 1, "
    "carga_gastos_enabled = 1, "
    "last_reparto_id = ?, "
    "recorrido_active = 0, "
    "recorrido_start_millis = NULL, "
    "recorrido_reparto_id = NULL, "
    "recorrido_day = -1, "
    "recorrido_client_statuses = '', "
    "active_recorridos_json = '[]', "
    "instances_json = '[]', "
    "settings_dirty = 0, "
    "settings_dirty_secure = 0, "
    "settings_dirty_prefs = 0, "
    "settings_dirty_mp = 0, "
    "settings_dirty_afip = 0, "
    "settings_dirty_recorrido = 0 "
    "WHERE id = 1",
    [repartoId],
  );

  final productIds = <int>[];
  for (final seed in _products) {
    final id = await db.createProduct(
      repartoId,
      seed.name,
      precio: seed.salePrice,
    );
    await db.createProductoPrecio(repartoId, id, 'Lista', seed.salePrice);
    await db.createProductoPrecio(
      repartoId,
      id,
      'Promo',
      seed.salePrice * 0.92,
    );
    await db.updateProductPrecioMayorista(id, seed.wholesalePrice);
    if (seed.packSize != null) {
      await db.setProductoPackSize(id, seed.packSize);
    }
    productIds.add(id);
  }

  for (var day = 0; day < 6; day++) {
    for (var i = 0; i < productIds.length; i++) {
      final seed = _products[i];
      await db.setCantidad(
        repartoId,
        productIds[i],
        day,
        todayWeek,
        day == todayDay ? seed.loaded : (seed.loaded * 0.7).round(),
        remanente: day == todayDay ? seed.remanente : 0,
      );
    }
  }

  final todayClientIds = <int>[];
  for (var day = 0; day < 6; day++) {
    for (var i = 0; i < _clients.length; i++) {
      final seed = _clients[(i + day) % _clients.length];
      final id = await db.createCliente(
        repartoId,
        day,
        seed.name,
        direccion: seed.address,
        telefono: seed.phone,
        frecuencia: i % 5 == 0 ? 'quincenal' : 'semanal',
        etiqueta: seed.etiqueta,
        notas: seed.notas,
        lat: seed.lat,
        lng: seed.lng,
      );
      if (day == todayDay) todayClientIds.add(id);
      await db.setClienteProducto(id, productIds[0], 1 + (i % 2));
      if (i % 3 != 0) await db.setClienteProducto(id, productIds[1], 1);
      if (i % 4 == 0) await db.setClienteProducto(id, productIds[2], 1);
    }
  }

  for (var i = 0; i < todayClientIds.length; i++) {
    final clientId = todayClientIds[i];
    final sodaQty = 1 + (i % 3);
    final aguaQty = i.isEven ? 1 : 0;
    await db.setEntrega(
      clientId,
      repartoId,
      productIds[0],
      lastWeek,
      todayDay,
      sodaQty,
      0,
      precioUnitario: _products[0].salePrice,
    );
    if (aguaQty > 0) {
      await db.setEntrega(
        clientId,
        repartoId,
        productIds[1],
        lastWeek,
        todayDay,
        aguaQty,
        0,
        precioUnitario: _products[1].salePrice,
      );
    }
    final amount =
        (sodaQty * _products[0].salePrice) + (aguaQty * _products[1].salePrice);
    await db.setPago(
      clientId,
      repartoId,
      lastWeek,
      todayDay,
      i % 4 == 0 ? 'transferencia' : 'efectivo',
      i == 2 ? amount * 0.5 : amount,
    );
  }

  await db.createResumen(
    repartoId: repartoId,
    fecha: fechaFromDisplayedSemana(lastWeek, todayDay),
    semana: lastWeek,
    diaSemana: todayDay,
    duracionSegundos: 3 * 3600 + 22 * 60,
    efectivo: 68400,
    transferencia: 39200,
    cuentaCorriente: 7200,
    gastos: 18400,
    sueldoBruto: 107600,
    sueldoNeto: 89200,
    productosJson: jsonEncode([
      {'nombre': 'Soda 12L', 'cargado': 38, 'vendido': 24, 'remanente': 6},
      {'nombre': 'Agua 20L', 'cargado': 24, 'vendido': 13, 'remanente': 3},
    ]),
    gastosJson: jsonEncode([
      {'descripcion': 'Nafta', 'monto': 12000},
      {'descripcion': 'Peaje', 'monto': 6400},
    ]),
  );

  await db.createResumen(
    repartoId: repartoId,
    fecha: fechaFromDisplayedSemana(lastMonthWeek, todayDay),
    semana: lastMonthWeek,
    diaSemana: todayDay,
    duracionSegundos: 3 * 3600 + 8 * 60,
    efectivo: 61200,
    transferencia: 28400,
    cuentaCorriente: 0,
    gastos: 15100,
    sueldoBruto: 89600,
    sueldoNeto: 74500,
    productosJson: jsonEncode([
      {'nombre': 'Soda 12L', 'cargado': 34, 'vendido': 22, 'remanente': 5},
      {'nombre': 'Agua 20L', 'cargado': 22, 'vendido': 11, 'remanente': 4},
    ]),
    gastosJson: jsonEncode([
      {'descripcion': 'Mantenimiento', 'monto': 15100},
    ]),
  );

  await _clearDirtyFlags(db);
}

Future<void> _clearDemoTables(AppDatabase db) async {
  const tables = [
    'pending_deletions',
    'tombstones_seen',
    'clientes_sync_conflicts',
    'app_notifications',
    'notif_dismissals',
    'facturas',
    'cliente_productos',
    'entregas',
    'pagos',
    'resumenes',
    'carga_diaria',
    'producto_precios',
    'stock_notif_settings',
    'habitual_product_settings',
    'etiqueta_colors',
    'clientes',
    'productos',
    'repartos',
    'cuentas_local',
  ];
  for (final table in tables) {
    if (await _tableExists(db, table)) {
      await db.customStatement('DELETE FROM $table');
    }
  }
}

Future<bool> _tableExists(AppDatabase db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
        variables: [Variable.withString(table)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<void> _clearDirtyFlags(AppDatabase db) async {
  const dirtyTables = [
    'repartos',
    'productos',
    'producto_precios',
    'clientes',
    'cliente_productos',
    'entregas',
    'pagos',
    'resumenes',
    'carga_diaria',
    'cuentas_local',
  ];
  for (final table in dirtyTables) {
    if (await _tableExists(db, table)) {
      await db.customStatement('UPDATE $table SET dirty = 0');
    }
  }
  if (await _tableExists(db, 'carga_diaria')) {
    await db.customStatement(
      'UPDATE carga_diaria SET cantidad_synced = cantidad, pending_push_id = NULL',
    );
  }
  await db.customStatement(
    'UPDATE user_settings SET '
    'settings_dirty = 0, '
    'settings_dirty_secure = 0, '
    'settings_dirty_prefs = 0, '
    'settings_dirty_mp = 0, '
    'settings_dirty_afip = 0, '
    'settings_dirty_recorrido = 0 '
    'WHERE id = 1',
  );
}
