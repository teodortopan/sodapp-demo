import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../utils/argentina_time.dart';
import '../utils/logical_clock.dart';
import '../utils/recorrido_merge.dart';
import '../utils/uid_gen.dart';

import '../utils/sueldo_formulas.dart';
import 'connection/vm.dart' if (dart.library.js_interop) 'connection/web.dart';

part 'app_database.g.dart';

class Repartos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get userId => text()();
  IntColumn get orden => integer().withDefault(const Constant(0))();
}

class Productos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repartoId => integer().nullable()();
  TextColumn get nombre => text()();
  IntColumn get orden => integer().withDefault(const Constant(0))();
  RealColumn get precio => real().withDefault(const Constant(0.0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

class CargaDiaria extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get repartoId => integer().references(Repartos, #id)();
  // 0=Lunes, 1=Martes, ... 5=Sábado
  IntColumn get diaSemana => integer()();
  // ISO week string like "2026-W11" to identify which week
  TextColumn get semana => text()();
  IntColumn get cantidad => integer().withDefault(const Constant(0))();
  IntColumn get remanente => integer().withDefault(const Constant(0))();
}

class Clientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repartoId => integer().references(Repartos, #id)();
  // 0=Lunes, 1=Martes, ... 5=Sábado
  IntColumn get diaSemana => integer()();
  TextColumn get nombre => text()();
  TextColumn get direccion => text().withDefault(const Constant(''))();
  TextColumn get telefono => text().withDefault(const Constant(''))();
  // semanal, quincenal, mensual
  TextColumn get frecuencia => text().withDefault(const Constant('semanal'))();
  TextColumn get etiqueta => text().withDefault(const Constant(''))();
  TextColumn get notas => text().withDefault(const Constant(''))();
  IntColumn get orden => integer().withDefault(const Constant(0))();
  RealColumn get cuentaCorriente => real().withDefault(const Constant(0.0))();
  BoolColumn get showOnMap => boolean().withDefault(const Constant(true))();
  // Factura: 99=Consumidor Final, 96=DNI, 80=CUIT
  IntColumn get docTipo => integer().withDefault(const Constant(99))();
  TextColumn get docNro => text().withDefault(const Constant('0'))();
}

class ClienteProductos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  IntColumn get productoId => integer().references(Productos, #id)();
  IntColumn get cantidadHabitual => integer().withDefault(const Constant(1))();
  // Selected price type for this client-product combo (null = use first/default)
  IntColumn get precioTipoId => integer().nullable()();
}

class Entregas extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  IntColumn get repartoId => integer().references(Repartos, #id)();
  IntColumn get productoId => integer().references(Productos, #id)();
  TextColumn get semana => text()();
  IntColumn get diaSemana => integer()();
  IntColumn get entregado => integer().withDefault(const Constant(0))();
  IntColumn get devuelto => integer().withDefault(const Constant(0))();
  RealColumn get precioUnitario => real().withDefault(const Constant(0.0))();
}

class Pagos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  IntColumn get repartoId => integer().references(Repartos, #id)();
  TextColumn get semana => text()();
  IntColumn get diaSemana => integer()();
  // 'efectivo', 'transferencia', 'no_pago'
  TextColumn get metodoPago => text()();
  RealColumn get monto => real().withDefault(const Constant(0.0))();
}

class UserSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Comma-separated day indices: "0,1,2,3,4,5" (Mon-Sat)
  TextColumn get workDays =>
      text().withDefault(const Constant('0,1,2,3,4,5'))();
  BoolColumn get qrEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get mapEnabled => boolean().withDefault(const Constant(true))();
  // Deuda notification: enabled + threshold in weeks
  BoolColumn get deudaNotifEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get deudaNotifWeeks => integer().withDefault(const Constant(3))();
  // Inactive client notification: enabled + threshold in weeks
  BoolColumn get inactiveNotifEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get inactiveNotifWeeks =>
      integer().withDefault(const Constant(4))();
  // Stock low notification: master toggle
  BoolColumn get stockNotifMasterEnabled =>
      boolean().withDefault(const Constant(true))();
  // Last selected reparto ID (persisted across app restarts)
  IntColumn get lastRepartoId => integer().nullable()();
  // AFIP / Facturación config
  TextColumn get afipToken => text().withDefault(const Constant(''))();
  TextColumn get afipCuit => text().withDefault(const Constant(''))();
  IntColumn get afipPtoVta => integer().withDefault(const Constant(0))();
  TextColumn get afipRazonSocial => text().withDefault(const Constant(''))();
  TextColumn get afipDomicilio => text().withDefault(const Constant(''))();
  TextColumn get afipCondicionIva =>
      text().withDefault(const Constant('Monotributista'))();
  BoolColumn get afipProduction =>
      boolean().withDefault(const Constant(false))();
  // Mercado Pago access token for QR cobrar
  TextColumn get mpAccessToken => text().withDefault(const Constant(''))();
}

/// Tracks dismissed notifications so they don't re-appear until the condition resets.
/// type: 'deuda_weeks', 'inactive_weeks', etc.
class NotifDismissals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer()();
  TextColumn get type => text()();
}

class AppNotifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 'deuda_weeks' (extensible for future types)
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  // Optional link to a client
  IntColumn get clienteId => integer().nullable()();
  TextColumn get createdAt => text()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
}

class AppNotificationWithMessageId {
  final AppNotification notification;
  final int? messageId;

  const AppNotificationWithMessageId({
    required this.notification,
    required this.messageId,
  });
}

class ProductoPrecios extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repartoId => integer().nullable()();
  IntColumn get productoId => integer().references(Productos, #id)();
  TextColumn get nombre => text()(); // e.g. "Base", "Descuento", "Mayorista"
  RealColumn get precio => real()();
  IntColumn get orden => integer().withDefault(const Constant(0))();
}

class Resumenes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repartoId => integer().references(Repartos, #id)();
  // Date of the recorrido (ISO format YYYY-MM-DD)
  TextColumn get fecha => text()();
  // Week string like "2026-W11"
  TextColumn get semana => text()();
  IntColumn get diaSemana => integer()();
  // Duration in seconds
  IntColumn get duracionSegundos => integer()();
  RealColumn get efectivo => real().withDefault(const Constant(0.0))();
  RealColumn get transferencia => real().withDefault(const Constant(0.0))();
  RealColumn get cuentaCorriente => real().withDefault(const Constant(0.0))();
  RealColumn get gastos => real().withDefault(const Constant(0.0))();
  RealColumn get sueldoBruto => real().withDefault(const Constant(0.0))();
  RealColumn get sueldoNeto => real().withDefault(const Constant(0.0))();
  // Timestamp for ordering (ISO 8601 with time)
  TextColumn get createdAt => text().withDefault(const Constant(''))();
  // JSON string for product balance and gastos detail
  TextColumn get productosJson => text().withDefault(const Constant(''))();
  TextColumn get gastosJson => text().withDefault(const Constant(''))();
}

class StockNotifSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repartoId => integer().nullable()();
  IntColumn get productoId => integer().references(Productos, #id)();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get threshold => integer().withDefault(const Constant(5))();
}

class Facturas extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  IntColumn get repartoId => integer().references(Repartos, #id)();
  // Factura C = 11, Nota Credito C = 13, Nota Debito C = 12
  IntColumn get cbteTipo => integer().withDefault(const Constant(11))();
  IntColumn get ptoVta => integer()();
  IntColumn get cbteNro => integer()();
  TextColumn get fecha => text()(); // YYYY-MM-DD
  RealColumn get importeTotal => real()();
  // CAE returned by AFIP
  TextColumn get cae => text()();
  TextColumn get caeFchVto => text()(); // YYYY-MM-DD
  // JSON of line items [{nombre, cantidad, precioUnit, subtotal}]
  TextColumn get itemsJson => text().withDefault(const Constant('[]'))();
  // Recipient info
  TextColumn get receptorNombre => text().withDefault(const Constant(''))();
  IntColumn get receptorDocTipo =>
      integer().withDefault(const Constant(99))(); // 99=consumidor final
  TextColumn get receptorDocNro => text().withDefault(const Constant('0'))();
  // Local PDF file path
  TextColumn get pdfPath => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text().withDefault(const Constant(''))();
}

class EtiquetaColors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repartoId => integer().references(Repartos, #id)();
  TextColumn get nombre => text()();
  // Stored as hex string e.g. 'FF1292D3'
  TextColumn get colorHex => text()();
}

@DriftDatabase(
  tables: [
    Repartos,
    Productos,
    ProductoPrecios,
    CargaDiaria,
    Clientes,
    ClienteProductos,
    Entregas,
    Pagos,
    Resumenes,
    UserSettings,
    EtiquetaColors,
    AppNotifications,
    NotifDismissals,
    StockNotifSettings,
    Facturas,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(openConnection());

  /// Test-only: run the real schema + helpers against an injected executor
  /// (e.g. `NativeDatabase.memory()`) so regression tests can exercise
  /// actual DB behavior without platform channels. Never use in app code —
  /// production always goes through [instance].
  @visibleForTesting
  AppDatabase.forTesting(super.e);

  /// P2-11 (pre-release audit #11): transaction-boundary hooks, wired by
  /// SyncService.startListening to beginLocalWrites/endLocalWrites so a
  /// realtime pull can never interleave with a compound local write.
  /// Static (not instance) so the wiring survives however the singleton is
  /// constructed; null until sync starts, so migrations / tests / the web
  /// admin run unaffected.
  static void Function()? onWriteTransactionStart;
  static void Function()? onWriteTransactionEnd;

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) async {
    // Balanced even on exceptions; nested transactions increment/decrement
    // symmetrically so the SyncService counter nets to zero.
    onWriteTransactionStart?.call();
    try {
      return await super.transaction(action, requireNew: requireNew);
    } finally {
      onWriteTransactionEnd?.call();
    }
  }

  static AppDatabase? _instance;
  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  /// Test-only: route the singleton at an in-memory [forTesting] database
  /// so services that reach for [instance] (e.g. SecureCredentials) can be
  /// exercised without platform channels. Pass null to reset.
  @visibleForTesting
  static set instanceForTesting(AppDatabase? db) {
    _instance = db;
  }

  final Set<void Function()> _dataListeners = {};
  final Set<void Function()> _localDataListeners = {};
  final Map<String, Timer> _resumenLiveRecalcTimers = {};
  final Map<String, ({int repartoId, String semana, int diaSemana})>
  _pendingResumenLiveRecalcs = {};
  void Function()? _legacyOnDataChanged;
  void Function()? _legacyOnLocalDataChanged;

  /// Legacy single callback triggered after any synced data mutation.
  ///
  /// New UI code should use [addDataListener] / [removeDataListener] so
  /// mounted screens do not overwrite each other's DB subscriptions.
  void Function()? get onDataChanged => _notifyDataChanged;
  set onDataChanged(void Function()? callback) {
    _legacyOnDataChanged = callback;
  }

  /// Legacy single callback for local-only UI changes that should not schedule
  /// cloud sync.
  void Function()? get onLocalDataChanged => _notifyLocalDataChanged;
  set onLocalDataChanged(void Function()? callback) {
    _legacyOnLocalDataChanged = callback;
  }

  void addDataListener(void Function() listener) {
    _dataListeners.add(listener);
  }

  void removeDataListener(void Function() listener) {
    _dataListeners.remove(listener);
  }

  void addLocalDataListener(void Function() listener) {
    _localDataListeners.add(listener);
  }

  void removeLocalDataListener(void Function() listener) {
    _localDataListeners.remove(listener);
  }

  void _notifyDataChanged() {
    _legacyOnDataChanged?.call();
    for (final listener in List<void Function()>.of(_dataListeners)) {
      listener();
    }
  }

  void _notifyLocalDataChanged() {
    _legacyOnLocalDataChanged?.call();
    for (final listener in List<void Function()>.of(_localDataListeners)) {
      listener();
    }
  }

  /// Set externally to block writes (used by demo mode)

  @override
  int get schemaVersion => 85;

  /// Test-only: re-execute the onUpgrade ladder from [from] → the current
  /// [schemaVersion], exactly as a production phone upgrading from a build
  /// at schema [from] would. Every gate ≥ the shipped field versions is
  /// written idempotently (\_ensureColumn / IF NOT EXISTS / guarded
  /// UPDATEs), so running it against an already-current database must be
  /// a no-op that neither throws nor mutates business data — the
  /// upgrade-regression test asserts precisely that.
  @visibleForTesting
  Future<void> rerunMigrationLadder(int from) async {
    await migration.onUpgrade(createMigrator(), from, schemaVersion);
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // Add recorrido persistence columns (managed via raw SQL, not Drift)
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN recorrido_active INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN recorrido_start_millis INTEGER',
      );
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN recorrido_reparto_id INTEGER',
      );
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN recorrido_day INTEGER NOT NULL DEFAULT -1',
      );
      await customStatement(
        "ALTER TABLE user_settings ADD COLUMN recorrido_client_statuses TEXT NOT NULL DEFAULT ''",
      );

      // Multi-recorrido JSON storage (v30)
      await customStatement(
        "ALTER TABLE user_settings ADD COLUMN active_recorridos_json TEXT NOT NULL DEFAULT '[]'",
      );

      // v85 — «Instancias»: per-reparto parallel day-views registry.
      // Entries: {id, repartoId, nombre, day, createdAtMs, updatedAtMs,
      // deleted?}. Synced cross-device through the recorrido section with
      // a per-entry merge (see lib/utils/recorrido_merge.dart).
      await customStatement(
        "ALTER TABLE user_settings ADD COLUMN instances_json TEXT NOT NULL DEFAULT '[]'",
      );

      // v48: optional auto-mark Listo when a payment method is tapped.
      // Off by default so existing soderos see no behavior change.
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN auto_listo_on_pago INTEGER NOT NULL DEFAULT 0',
      );
      await _ensureColumn(
        'user_settings',
        'carga_gastos_enabled',
        'INTEGER NOT NULL DEFAULT 1',
      );

      // v61: which non-essential fields show up on each cliente row in
      // Ruta's vista rápida. CSV of keys: saldo, frecuencia, etiquetas,
      // notas. Defaults to all four enabled so existing users see no
      // visual change.
      await customStatement(
        "ALTER TABLE user_settings ADD COLUMN vista_rapida_fields TEXT NOT NULL DEFAULT 'saldo,frecuencia,etiquetas,notas'",
      );

      // v62: recorrido start/end UTC-epoch millis on resumenes. Nullable
      // for back-compat. Local-only — not pushed to cloud (the shift
      // duration is already in `duracionSegundos` which IS synced; these
      // two extra timestamps are per-device per-shift telemetry).
      await customStatement(
        'ALTER TABLE resumenes ADD COLUMN start_millis INTEGER',
      );
      await customStatement(
        'ALTER TABLE resumenes ADD COLUMN end_millis INTEGER',
      );
      await customStatement(
        "ALTER TABLE resumenes ADD COLUMN sessions_json TEXT NOT NULL DEFAULT '[]'",
      );
      // v63: optional pack metadata on productos. NULL or 0 = not a pack;
      // any positive int = units per pack. Aggregations divide by this when
      // summing pack products so the sodero sees pack counts in totals.
      await customStatement(
        'ALTER TABLE productos ADD COLUMN pack_size INTEGER',
      );
      await customStatement(
        'ALTER TABLE productos ADD COLUMN precio_dirty INTEGER NOT NULL DEFAULT 0',
      );
      await _ensureColumn('productos', 'precio_mayorista', 'REAL');
      await _ensureColumn(
        'productos',
        'precio_mayorista_dirty',
        'INTEGER NOT NULL DEFAULT 0',
      );
      // v78: per-column dirty flag for pack_size (mirrors precio_dirty) so a
      // local pack edit isn't clobbered by a stale cloud value on the next pull.
      await _ensureColumn(
        'productos',
        'pack_size_dirty',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE carga_diaria ADD COLUMN cantidad_synced INTEGER NOT NULL DEFAULT 0',
      );
      await _ensureColumn('carga_diaria', 'pending_push_id', 'TEXT');
      // P0-1 audit discovery: remanente was only added in onUpgrade (v32 /
      // v37 heal) — createAll's generated schema predates it, so FRESH
      // installs got a carga_diaria without the column and crashed on the
      // first remanente read/write or cloud restore. Same fresh-install
      // completeness gap as doc_nro_cache below. _ensureColumn keeps this
      // safe if the generated schema ever catches up.
      await _ensureColumn(
        'carga_diaria',
        'remanente',
        'INTEGER NOT NULL DEFAULT 0',
      );

      // v65: monthly subscription paid flag. Cloud is the source of
      // truth — the admin toggles this in the Supabase user_settings
      // row when the sodero pays. Local default is 0 (unpaid) so a
      // new sodero sees the reminder until the admin marks them paid.
      // Mobile NEVER pushes this column — pull-only.
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN subscription_paid INTEGER NOT NULL DEFAULT 0',
      );
      await _ensureColumn(
        'user_settings',
        'admin_message_banner_enabled',
        'INTEGER NOT NULL DEFAULT 1',
      );

      // v49: one-day "borrow" override for cliente day. temp_dia_semana wins
      // over dia_semana when temp_dia_date matches today's local yyyy-MM-dd.
      // Past dates fall through naturally — no cleanup timer needed.
      // Local-only (not in Drift Table, not in sync_service push/restore) —
      // a transient per-device convenience.
      await customStatement(
        'ALTER TABLE clientes ADD COLUMN temp_dia_semana INTEGER',
      );
      await customStatement(
        'ALTER TABLE clientes ADD COLUMN temp_dia_date TEXT',
      );
      await customStatement(
        'ALTER TABLE clientes ADD COLUMN marked_semana TEXT;',
      );

      await customStatement(
        "INSERT OR IGNORE INTO user_settings (id, work_days, qr_enabled) VALUES (1, '0,1,2,3,4,5', 1)",
      );

      // Habitual product settings (v33)
      await customStatement('''
            CREATE TABLE IF NOT EXISTS habitual_product_settings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              reparto_id INTEGER,
              producto_id INTEGER NOT NULL REFERENCES productos(id),
              enabled INTEGER NOT NULL DEFAULT 1
            )
          ''');

      // settings_dirty counter (v34)
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN settings_dirty INTEGER NOT NULL DEFAULT 0',
      );

      // Pending cloud deletions tombstones (v35, user_id added v36)
      await customStatement('''
            CREATE TABLE IF NOT EXISTS pending_deletions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              table_name TEXT NOT NULL,
              row_id INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              user_id TEXT,
              key_json TEXT,
              UNIQUE(table_name, row_id)
            )
          ''');

      // Geocoding cache columns (Issue 6: web admin geocode dedupe)
      await customStatement('ALTER TABLE clientes ADD COLUMN lat REAL');
      await customStatement('ALTER TABLE clientes ADD COLUMN lng REAL');
      await customStatement(
        'ALTER TABLE clientes ADD COLUMN geocoded_direccion TEXT',
      );

      // v31: doc_nro_cache JSON column for cached AFIP DocNro lookups.
      // The v31 migration in onUpgrade adds this on existing installs;
      // onCreate must also add it for FRESH installs — otherwise the
      // setClienteDocNroCache / getClienteDocNroCache helpers throw
      // "no such column" the first time AFIP invoicing runs on a new
      // device. Pre-existing bug surfaced after Codex audit identified
      // the fresh-deployment-completeness gap.
      await customStatement(
        "ALTER TABLE clientes ADD COLUMN doc_nro_cache TEXT NOT NULL DEFAULT '{}'",
      );

      // UNIQUE indexes for atomic UPSERT (Issues 1, 3)
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_entregas_unique ON entregas(cliente_id, reparto_id, producto_id, semana, dia_semana)',
      );
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_pagos_unique ON pagos(cliente_id, reparto_id, semana, dia_semana)',
      );
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_carga_diaria_unique ON carga_diaria(reparto_id, producto_id, dia_semana, semana)',
      );

      // P0.5 (v47): updated_at + dirty columns on business tables.
      // updated_at = ms since epoch when this row was last locally
      // mutated; dirty = 1 when local has unpushed changes. The cloud
      // restore path skips overwriting a row whose local copy is dirty
      // and newer.
      await customStatement(
        'ALTER TABLE entregas ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE entregas ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE pagos ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE pagos ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE carga_diaria ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE carga_diaria ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0',
      );

      // Wave 0 / v67: canonical fecha columns and audit-ledger schema.
      await _addFechaColumns();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_entregas_fecha ON entregas(fecha)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos(fecha)',
      );
      await _createCcAuditLogSchema();
      await _backfillFechaColumns();

      // Wave 2 remainder / v69: app-open backstop stamp for CC rows whose
      // future fecha has now entered the calculation window.
      await customStatement(
        'ALTER TABLE user_settings '
        "ADD COLUMN last_cc_expiry_recompute_date TEXT NOT NULL DEFAULT ''",
      );
      await _ensureMessagingSchema();

      // P0.6 (v47): cuentas_local stores profile in Drift. Replaces the
      // direct-cloud writes from ProfileScreen that caused the
      // blank-out bug. Sync pushes dirty rows to cloud `cuentas`.
      // v50: foto_path (local file on device) + foto_url (cloud Storage
      // URL, synced via cuentas). foto_path is local-only; foto_url
      // travels with the cuentas push/restore so the photo follows the
      // sodero across devices.
      // v51: foto_dirty scopes foto_url pushes so older dirty profile rows
      // cannot blank the cloud photo. foto_upload_pending_path stores the
      // local file to retry after an offline pick.
      await customStatement('''
            CREATE TABLE IF NOT EXISTS cuentas_local (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL UNIQUE,
              email TEXT NOT NULL DEFAULT '',
              nombre TEXT NOT NULL DEFAULT '',
              telefono TEXT NOT NULL DEFAULT '',
              foto_path TEXT NOT NULL DEFAULT '',
              foto_url TEXT NOT NULL DEFAULT '',
              foto_dirty INTEGER NOT NULL DEFAULT 0,
              foto_upload_pending_path TEXT NOT NULL DEFAULT '',
              updated_at INTEGER NOT NULL DEFAULT 0,
              dirty INTEGER NOT NULL DEFAULT 0
            )
          ''');

      // v52: extend the v47 dirty/updated_at pattern to clientes,
      // cliente_productos, and resumenes. Mobile sync now pushes only
      // dirty=1 rows; without these columns local edits to clientes /
      // cliente_productos / resumenes would never push at all. Default
      // 0 on both columns is safe — first-time installs pull-restore
      // from cloud (sets dirty=0, updated_at from cloud), and pre-v52
      // installs are handled in the onUpgrade branch below.
      await customStatement(
        'ALTER TABLE clientes ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE clientes ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        "ALTER TABLE clientes ADD COLUMN dirty_fields TEXT NOT NULL DEFAULT ''",
      );
      await customStatement(
        'ALTER TABLE cliente_productos ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE cliente_productos ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE resumenes ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE resumenes ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0',
      );
      await _ensurePerformanceIndexes();

      // Phase 2 / v53: per-section dirty counters on user_settings. The
      // singleton row holds AFIP/MP credentials AND UI preferences in one
      // place; a single dirty flag meant any preference toggle (e.g. qr
      // on/off) would push the WHOLE row, overwriting another device's
      // AFIP token edit. Split into two counters so each section pushes
      // independently:
      //   - settings_dirty_secure → AFIP credentials + Mercado Pago token
      //   - settings_dirty_prefs  → everything else synced (workdays,
      //     toggles, notifications)
      // The legacy `settings_dirty` counter is still bumped by both new
      // helpers for backward compatibility with existing read sites.
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN settings_dirty_secure INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN settings_dirty_prefs INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN settings_dirty_mp INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN settings_dirty_afip INTEGER NOT NULL DEFAULT 0',
      );

      // Phase 3 / v54: tombstones_seen — local idempotency record of cloud
      // tombstones already applied to this device. Lets _pullTombstones
      // skip already-processed rows without resorting to "DELETE FROM …
      // WHERE id = ?" no-ops on every realtime tick. Composite PK on
      // (user_id, table_name, row_id) so simultaneous tombstones for
      // different rows / users / tables don't collide.
      await customStatement('''
            CREATE TABLE IF NOT EXISTS tombstones_seen (
              user_id TEXT NOT NULL,
              table_name TEXT NOT NULL,
              row_id INTEGER NOT NULL,
              deleted_at INTEGER NOT NULL,
              PRIMARY KEY (user_id, table_name, row_id)
            )
          ''');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_tombstones_seen_user_deleted_at '
        'ON tombstones_seen(user_id, deleted_at)',
      );

      // Phase 2 remainder / v55: dirty + updated_at on the 7 full-upload
      // tables. Mirrors the v47/v52 pattern for entregas/clientes/etc.
      // Without these columns the mobile push code stamps DateTime.now()
      // and the cloud reject_stale_update trigger rubber-stamps the stale
      // payload (mobile always looks "newer" than reality). With the local
      // updated_at column, the push sends the actual edit time and the
      // trigger arbitrates honestly.
      for (final t in const [
        'productos',
        'repartos',
        'producto_precios',
        'stock_notif_settings',
        'habitual_product_settings',
        'facturas',
        'etiqueta_colors',
      ]) {
        await customStatement(
          'ALTER TABLE $t ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE $t ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0',
        );
      }

      // Phase 6 / v56: active recorrido cross-device sync (behind feature
      // flag). Three new columns on the user_settings singleton:
      //   • settings_dirty_recorrido — per-section dirty counter (matches
      //     the v53 secure/prefs split). Lets the push code send the
      //     active_recorridos_json column on its own, independent of
      //     AFIP/prefs section pushes.
      //   • active_recorridos_json_prev — snapshot of the previous local
      //     value before an inbound cloud apply overwrites it. Restores
      //     are available via the snapshot, opening the door to a future
      //     "undo" affordance on the recorrido screen.
      //   • sync_recorrido_enabled — feature flag. Was per-device opt-in
      //     (DEFAULT 0) pre-v85; «Instancias» needs cross-device recorrido
      //     state, so fresh installs now start ON (the v85 migration heals
      //     upgraders, and the cloud column has defaulted to 1 since the
      //     v56 cloud follow-up — the pull keeps every device aligned).
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN settings_dirty_recorrido INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        "ALTER TABLE user_settings ADD COLUMN active_recorridos_json_prev TEXT NOT NULL DEFAULT ''",
      );
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN sync_recorrido_enabled INTEGER NOT NULL DEFAULT 1',
      );

      // Phase 4 / v57: cross-device collision-proof row identifier.
      // Every business table grows a nullable `uid TEXT` column. The
      // mobile push generates a UUID v7 on demand (at push time) for
      // any row whose uid is still null; the pull propagates cloud's
      // uid (gen_random_uuid v4 from cloud backfill) back into local.
      // The columns coexist with the existing autoincrement `id` —
      // `id` stays primary key, `uid` is the cross-device tiebreaker.
      //
      // No backfill for fresh installs (no existing rows). Upgrades
      // backfill lazily — the push path stamps missing uids per row.
      // Existing autoincrement IDs continue to work; this is purely
      // additive.
      for (final t in const [
        'productos',
        'repartos',
        'clientes',
        'cliente_productos',
        'carga_diaria',
        'entregas',
        'pagos',
        'resumenes',
        'producto_precios',
        'stock_notif_settings',
        'habitual_product_settings',
        'facturas',
        'etiqueta_colors',
      ]) {
        await customStatement('ALTER TABLE $t ADD COLUMN uid TEXT');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_${t}_uid ON $t(uid)',
        );
      }
      await customStatement(
        'ALTER TABLE user_settings ADD COLUMN sync_uid_enabled INTEGER NOT NULL DEFAULT 0',
      );

      await customStatement('''
            CREATE TABLE IF NOT EXISTS clientes_sync_conflicts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              cliente_id INTEGER NOT NULL,
              detected_at INTEGER NOT NULL,
              reason TEXT NOT NULL,
              local_json TEXT NOT NULL,
              cloud_json TEXT NOT NULL
            )
          ''');

      // P0-2 / v80 (audit #2): per-device AUTOINCREMENT id ranges. See
      // seedDeviceIdRanges — fresh installs allocate every new row id
      // inside this device's own random multi-billion range so two
      // devices on one account can never mint the same id offline.
      await seedDeviceIdRanges();

      // P1-8 / v81 (audit #8): one resumen per (reparto, fecha, dia) —
      // fresh installs get the UNIQUE index from day one.
      await dedupeAndIndexResumenes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(repartos);
        await customStatement('DROP TABLE IF EXISTS carga_diaria');
        await m.createTable(cargaDiaria);
      }
      if (from < 3) {
        await customStatement('DROP TABLE IF EXISTS clientes');
        await customStatement('DROP TABLE IF EXISTS cliente_productos');
        await customStatement('DROP TABLE IF EXISTS entregas');
        await customStatement('DROP TABLE IF EXISTS pagos');
        await m.createTable(clientes);
        await m.createTable(clienteProductos);
        await m.createTable(entregas);
        await m.createTable(pagos);
      }
      if (from >= 3 && from < 5) {
        // Recreate clientes with all columns
        await customStatement('DROP TABLE IF EXISTS entregas');
        await customStatement('DROP TABLE IF EXISTS pagos');
        await customStatement('DROP TABLE IF EXISTS cliente_productos');
        await customStatement('DROP TABLE IF EXISTS clientes');
        await m.createTable(clientes);
        await m.createTable(clienteProductos);
        await m.createTable(entregas);
        await m.createTable(pagos);
      }
      if (from < 6) {
        await m.createTable(resumenes);
      }
      if (from < 7) {
        await customStatement(
          'ALTER TABLE clientes ADD COLUMN cuenta_corriente REAL NOT NULL DEFAULT 0.0',
        );
      }
      if (from < 8) {
        await m.createTable(userSettings);
        // Seed default settings row
        await customStatement(
          "INSERT OR IGNORE INTO user_settings (id, work_days, qr_enabled) VALUES (1, '0,1,2,3,4,5', 1)",
        );
      }
      if (from < 9) {
        await customStatement(
          'ALTER TABLE productos ADD COLUMN precio REAL NOT NULL DEFAULT 0.0',
        );
      }
      if (from < 10) {
        await m.createTable(productoPrecios);
        await customStatement(
          'ALTER TABLE cliente_productos ADD COLUMN precio_tipo_id INTEGER',
        );
        // Migrate existing product prices into producto_precios as "Base" entries
        final existingProducts = await customSelect(
          'SELECT id, precio FROM productos WHERE precio > 0',
        ).get();
        for (final row in existingProducts) {
          final productId = row.read<int>('id');
          final precio = row.read<double>('precio');
          await customStatement(
            'INSERT INTO producto_precios (producto_id, nombre, precio, orden) VALUES (?, ?, ?, 0)',
            [productId, 'Base', precio],
          );
        }
      }
      if (from < 11) {
        await customStatement(
          "ALTER TABLE resumenes ADD COLUMN created_at TEXT NOT NULL DEFAULT ''",
        );
      }
      if (from < 12) {
        await customStatement(
          "ALTER TABLE clientes ADD COLUMN show_on_map INTEGER NOT NULL DEFAULT 1",
        );
      }
      if (from < 13) {
        await m.createTable(etiquetaColors);
      }
      if (from < 14) {
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN map_enabled INTEGER NOT NULL DEFAULT 1",
        );
      }
      if (from < 15) {
        await m.createTable(appNotifications);
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN deuda_notif_enabled INTEGER NOT NULL DEFAULT 1",
        );
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN deuda_notif_weeks INTEGER NOT NULL DEFAULT 3",
        );
      }
      if (from < 16) {
        // Old table — will be replaced by notif_dismissals in v17
        await customStatement(
          'CREATE TABLE IF NOT EXISTS deuda_notif_dismissals (id INTEGER PRIMARY KEY AUTOINCREMENT, cliente_id INTEGER NOT NULL)',
        );
      }
      if (from < 17) {
        await m.createTable(notifDismissals);
        // Migrate old deuda dismissals
        await customStatement(
          "INSERT INTO notif_dismissals (cliente_id, type) SELECT cliente_id, 'deuda_weeks' FROM deuda_notif_dismissals",
        );
        await customStatement('DROP TABLE IF EXISTS deuda_notif_dismissals');
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN inactive_notif_enabled INTEGER NOT NULL DEFAULT 1",
        );
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN inactive_notif_weeks INTEGER NOT NULL DEFAULT 4",
        );
      }
      if (from < 18) {
        await m.createTable(stockNotifSettings);
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN stock_notif_master_enabled INTEGER NOT NULL DEFAULT 1",
        );
        // Create default entries for all existing products
        final products = await customSelect('SELECT id FROM productos').get();
        for (final row in products) {
          final productId = row.read<int>('id');
          await customStatement(
            'INSERT OR IGNORE INTO stock_notif_settings (producto_id, enabled, threshold) VALUES (?, 1, 5)',
            [productId],
          );
        }
      }
      if (from < 19) {
        await customStatement(
          'ALTER TABLE entregas ADD COLUMN precio_unitario REAL NOT NULL DEFAULT 0.0',
        );
      }
      if (from < 20) {
        await customStatement(
          'ALTER TABLE resumenes ADD COLUMN sueldo_bruto REAL NOT NULL DEFAULT 0.0',
        );
      }
      if (from < 21) {
        await customStatement(
          'ALTER TABLE productos ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 22) {
        await customStatement(
          'ALTER TABLE user_settings ADD COLUMN last_reparto_id INTEGER',
        );
      }
      if (from < 23) {
        await m.createTable(facturas);
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN afip_token TEXT NOT NULL DEFAULT ''",
        );
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN afip_cuit TEXT NOT NULL DEFAULT ''",
        );
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN afip_pto_vta INTEGER NOT NULL DEFAULT 0",
        );
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN afip_razon_social TEXT NOT NULL DEFAULT ''",
        );
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN afip_domicilio TEXT NOT NULL DEFAULT ''",
        );
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN afip_condicion_iva TEXT NOT NULL DEFAULT 'Monotributista'",
        );
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN afip_production INTEGER NOT NULL DEFAULT 0",
        );
      }
      if (from < 24) {
        await customStatement(
          "ALTER TABLE clientes ADD COLUMN doc_tipo INTEGER NOT NULL DEFAULT 99",
        );
        await customStatement(
          "ALTER TABLE clientes ADD COLUMN doc_nro TEXT NOT NULL DEFAULT '0'",
        );
      }
      if (from < 25) {
        // Add reparto_id to productos, producto_precios, stock_notif_settings
        await customStatement(
          'ALTER TABLE productos ADD COLUMN reparto_id INTEGER',
        );
        await customStatement(
          'ALTER TABLE producto_precios ADD COLUMN reparto_id INTEGER',
        );
        await customStatement(
          'ALTER TABLE stock_notif_settings ADD COLUMN reparto_id INTEGER',
        );

        // Migrate: assign existing products to the first reparto
        final existingRepartos = await customSelect(
          'SELECT id FROM repartos ORDER BY orden',
        ).get();
        if (existingRepartos.isNotEmpty) {
          final firstRepartoId = existingRepartos.first.read<int>('id');

          // Assign all existing productos to first reparto
          await customStatement('UPDATE productos SET reparto_id = ?', [
            firstRepartoId,
          ]);
          await customStatement('UPDATE producto_precios SET reparto_id = ?', [
            firstRepartoId,
          ]);
          await customStatement(
            'UPDATE stock_notif_settings SET reparto_id = ?',
            [firstRepartoId],
          );

          // For additional repartos, duplicate products with new IDs
          for (int r = 1; r < existingRepartos.length; r++) {
            final repartoId = existingRepartos[r].read<int>('id');
            final origProducts = await customSelect(
              'SELECT id, nombre, orden, precio, deleted FROM productos WHERE reparto_id = ?',
              variables: [Variable.withInt(firstRepartoId)],
            ).get();

            for (final p in origProducts) {
              final oldId = p.read<int>('id');
              await customStatement(
                'INSERT INTO productos (reparto_id, nombre, orden, precio, deleted) VALUES (?, ?, ?, ?, ?)',
                [
                  repartoId,
                  p.read<String>('nombre'),
                  p.read<int>('orden'),
                  p.read<double>('precio'),
                  p.readNullable<int>('deleted') ?? 0,
                ],
              );
              final newIdResult = await customSelect(
                'SELECT last_insert_rowid() AS id',
              ).getSingle();
              final newId = newIdResult.read<int>('id');

              // Duplicate producto_precios
              final origPP = await customSelect(
                'SELECT nombre, precio, orden FROM producto_precios WHERE producto_id = ? AND reparto_id = ?',
                variables: [
                  Variable.withInt(oldId),
                  Variable.withInt(firstRepartoId),
                ],
              ).get();
              for (final pp in origPP) {
                await customStatement(
                  'INSERT INTO producto_precios (reparto_id, producto_id, nombre, precio, orden) VALUES (?, ?, ?, ?, ?)',
                  [
                    repartoId,
                    newId,
                    pp.read<String>('nombre'),
                    pp.read<double>('precio'),
                    pp.read<int>('orden'),
                  ],
                );
              }

              // Duplicate stock_notif_settings
              final origSNS = await customSelect(
                'SELECT enabled, threshold FROM stock_notif_settings WHERE producto_id = ? AND reparto_id = ?',
                variables: [
                  Variable.withInt(oldId),
                  Variable.withInt(firstRepartoId),
                ],
              ).get();
              for (final sns in origSNS) {
                await customStatement(
                  'INSERT INTO stock_notif_settings (reparto_id, producto_id, enabled, threshold) VALUES (?, ?, ?, ?)',
                  [
                    repartoId,
                    newId,
                    sns.read<int>('enabled'),
                    sns.read<int>('threshold'),
                  ],
                );
              }

              // Remap carga_diaria, cliente_productos, entregas for this reparto
              await customStatement(
                'UPDATE carga_diaria SET producto_id = ? WHERE reparto_id = ? AND producto_id = ?',
                [newId, repartoId, oldId],
              );
              // Update cliente_productos for clients belonging to this reparto
              await customStatement(
                'UPDATE cliente_productos SET producto_id = ? WHERE producto_id = ? AND cliente_id IN (SELECT id FROM clientes WHERE reparto_id = ?)',
                [newId, oldId, repartoId],
              );
              await customStatement(
                'UPDATE entregas SET producto_id = ? WHERE reparto_id = ? AND producto_id = ?',
                [newId, repartoId, oldId],
              );
            }
          }
        }
      }
      if (from < 26) {
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN mp_access_token TEXT NOT NULL DEFAULT ''",
        );
      }
      if (from < 27) {
        // Repair: assign NULL reparto_id products/precios to the first reparto
        final rows = await customSelect(
          'SELECT id FROM repartos ORDER BY orden LIMIT 1',
        ).get();
        if (rows.isNotEmpty) {
          final firstId = rows.first.read<int>('id');
          await customStatement(
            'UPDATE productos SET reparto_id = ? WHERE reparto_id IS NULL',
            [firstId],
          );
          await customStatement(
            'UPDATE producto_precios SET reparto_id = ? WHERE reparto_id IS NULL',
            [firstId],
          );
        }
        // Deduplicate: remove products with same name+reparto_id+precio, keep lowest ID.
        // Only removes true duplicates (same name AND same price), preserving
        // legitimately different products that happen to share a name.
        await customStatement('''
              DELETE FROM productos WHERE id NOT IN (
                SELECT MIN(id) FROM productos GROUP BY reparto_id, nombre, precio
              )
            ''');
        // Deduplicate producto_precios: same producto_id+reparto_id+nombre+precio
        await customStatement('''
              DELETE FROM producto_precios WHERE id NOT IN (
                SELECT MIN(id) FROM producto_precios GROUP BY reparto_id, producto_id, nombre, precio
              )
            ''');
      }
      if (from < 28) {
        // Change qr_enabled default to true for existing users
        await customStatement(
          'UPDATE user_settings SET qr_enabled = 1 WHERE qr_enabled = 0',
        );
      }
      if (from < 29) {
        // Persist active recorrido state so it survives app kill
        await customStatement(
          'ALTER TABLE user_settings ADD COLUMN recorrido_active INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE user_settings ADD COLUMN recorrido_start_millis INTEGER',
        );
        await customStatement(
          'ALTER TABLE user_settings ADD COLUMN recorrido_reparto_id INTEGER',
        );
        await customStatement(
          'ALTER TABLE user_settings ADD COLUMN recorrido_day INTEGER NOT NULL DEFAULT -1',
        );
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN recorrido_client_statuses TEXT NOT NULL DEFAULT ''",
        );
      }
      if (from < 30) {
        // Multi-recorrido JSON storage: array of {repartoId, startMillis, day, clientStatuses}
        await customStatement(
          "ALTER TABLE user_settings ADD COLUMN active_recorridos_json TEXT NOT NULL DEFAULT '[]'",
        );
      }
      if (from < 31) {
        await customStatement(
          "ALTER TABLE clientes ADD COLUMN doc_nro_cache TEXT NOT NULL DEFAULT '{}'",
        );
      }
      if (from < 32) {
        await customStatement(
          'ALTER TABLE carga_diaria ADD COLUMN remanente INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 33) {
        await customStatement('''
              CREATE TABLE IF NOT EXISTS habitual_product_settings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                reparto_id INTEGER,
                producto_id INTEGER NOT NULL REFERENCES productos(id),
                enabled INTEGER NOT NULL DEFAULT 1
              )
            ''');
      }
      if (from < 34) {
        // Persistent pending-push counter for user_settings.
        // Bumped by setters, cleared after successful push. Survives app kill
        // so local edits aren't overwritten by stale cloud on next launch.
        await customStatement(
          'ALTER TABLE user_settings ADD COLUMN settings_dirty INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 35) {
        // Tombstones for local deletions that still need to reach cloud.
        // Survives app kill so a delete-then-close-before-sync doesn't
        // resurrect on next launch's restore.
        await customStatement('''
              CREATE TABLE IF NOT EXISTS pending_deletions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                table_name TEXT NOT NULL,
                row_id INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                key_json TEXT,
                UNIQUE(table_name, row_id)
              )
            ''');
      }
      if (from < 36) {
        await customStatement(
          'ALTER TABLE pending_deletions ADD COLUMN user_id TEXT',
        );
      }
      if (from < 37) {
        // Defensive: some DBs at v32+ never actually got the remanente
        // column (migration skipped or interrupted). Ensure it exists.
        final cols = await customSelect(
          "PRAGMA table_info(carga_diaria)",
        ).get();
        final hasRemanente = cols.any(
          (r) => r.read<String>('name') == 'remanente',
        );
        if (!hasRemanente) {
          await customStatement(
            'ALTER TABLE carga_diaria ADD COLUMN remanente INTEGER NOT NULL DEFAULT 0',
          );
        }
      }
      if (from < 46) {
        // Idempotent block covering all paths from any prior version up to
        // 45. Adds geocoding cache columns (Issue 6), archives + dedupes
        // existing duplicate rows, then adds UNIQUE indexes for atomic
        // UPSERT (Issues 1, 3). The _ensureColumn / IF NOT EXISTS guards
        // make this safe to re-run.
        //
        // P3.3: dedupe ARCHIVES discarded rows into *_archive tables
        // before deleting. If a duplicate represented two real concurrent
        // writes (e.g. different qty for the same key), we never want to
        // lose the data — recovery via SQL is possible from the archive.
        await _ensureColumn('clientes', 'lat', 'REAL');
        await _ensureColumn('clientes', 'lng', 'REAL');
        await _ensureColumn('clientes', 'geocoded_direccion', 'TEXT');

        // Archive tables (idempotent — safe to re-run).
        await customStatement('''
              CREATE TABLE IF NOT EXISTS entregas_archive (
                archive_id INTEGER PRIMARY KEY AUTOINCREMENT,
                original_id INTEGER, cliente_id INTEGER, reparto_id INTEGER,
                producto_id INTEGER, semana TEXT, dia_semana INTEGER,
                entregado INTEGER, devuelto INTEGER, precio_unitario REAL,
                archived_at TEXT NOT NULL, archived_reason TEXT NOT NULL
              )
            ''');
        await customStatement('''
              CREATE TABLE IF NOT EXISTS pagos_archive (
                archive_id INTEGER PRIMARY KEY AUTOINCREMENT,
                original_id INTEGER, cliente_id INTEGER, reparto_id INTEGER,
                semana TEXT, dia_semana INTEGER,
                metodo_pago TEXT, monto REAL,
                archived_at TEXT NOT NULL, archived_reason TEXT NOT NULL
              )
            ''');
        await customStatement('''
              CREATE TABLE IF NOT EXISTS carga_diaria_archive (
                archive_id INTEGER PRIMARY KEY AUTOINCREMENT,
                original_id INTEGER, producto_id INTEGER, reparto_id INTEGER,
                dia_semana INTEGER, semana TEXT,
                cantidad INTEGER, remanente INTEGER,
                archived_at TEXT NOT NULL, archived_reason TEXT NOT NULL
              )
            ''');

        // Archive entregas duplicates BEFORE deleting them. Survivors
        // (highest id per natural key) stay; losers go to the archive.
        await customStatement('''
              INSERT INTO entregas_archive
                (original_id, cliente_id, reparto_id, producto_id, semana, dia_semana,
                 entregado, devuelto, precio_unitario, archived_at, archived_reason)
              SELECT id, cliente_id, reparto_id, producto_id, semana, dia_semana,
                     entregado, devuelto, precio_unitario,
                     datetime('now'), 'v46_dedupe'
              FROM entregas
              WHERE id NOT IN (
                SELECT MAX(id) FROM entregas
                GROUP BY cliente_id, reparto_id, producto_id, semana, dia_semana
              )
            ''');
        await customStatement('''
              DELETE FROM entregas WHERE id NOT IN (
                SELECT MAX(id) FROM entregas
                GROUP BY cliente_id, reparto_id, producto_id, semana, dia_semana
              )
            ''');

        // Archive pagos duplicates BEFORE deleting.
        await customStatement('''
              INSERT INTO pagos_archive
                (original_id, cliente_id, reparto_id, semana, dia_semana,
                 metodo_pago, monto, archived_at, archived_reason)
              SELECT id, cliente_id, reparto_id, semana, dia_semana,
                     metodo_pago, monto,
                     datetime('now'), 'v46_dedupe'
              FROM pagos
              WHERE id NOT IN (
                SELECT MAX(id) FROM pagos
                GROUP BY cliente_id, reparto_id, semana, dia_semana
              )
            ''');
        await customStatement('''
              DELETE FROM pagos WHERE id NOT IN (
                SELECT MAX(id) FROM pagos
                GROUP BY cliente_id, reparto_id, semana, dia_semana
              )
            ''');

        // Archive ALL carga_diaria rows that participate in any dupe
        // group BEFORE we coalesce + dedupe. Capturing every row lets us
        // recover any pre-merge value if needed (max-coalesce can hide
        // smaller-but-valid values).
        await customStatement('''
              INSERT INTO carga_diaria_archive
                (original_id, producto_id, reparto_id, dia_semana, semana,
                 cantidad, remanente, archived_at, archived_reason)
              SELECT cd.id, cd.producto_id, cd.reparto_id, cd.dia_semana, cd.semana,
                     cd.cantidad, cd.remanente,
                     datetime('now'), 'v46_dedupe_pre_merge'
              FROM carga_diaria cd
              WHERE EXISTS (
                SELECT 1 FROM carga_diaria c2
                WHERE c2.reparto_id = cd.reparto_id
                  AND c2.producto_id = cd.producto_id
                  AND c2.dia_semana = cd.dia_semana
                  AND c2.semana = cd.semana
                  AND c2.id != cd.id
              )
            ''');
        // Coalesce MAX values into surviving carga_diaria row before
        // deleting dupes, so we don't lose a higher cantidad/remanente.
        await customStatement('''
              UPDATE carga_diaria SET
                cantidad = (SELECT MAX(cantidad) FROM carga_diaria c2 WHERE c2.reparto_id = carga_diaria.reparto_id AND c2.producto_id = carga_diaria.producto_id AND c2.dia_semana = carga_diaria.dia_semana AND c2.semana = carga_diaria.semana),
                remanente = (SELECT MAX(remanente) FROM carga_diaria c2 WHERE c2.reparto_id = carga_diaria.reparto_id AND c2.producto_id = carga_diaria.producto_id AND c2.dia_semana = carga_diaria.dia_semana AND c2.semana = carga_diaria.semana)
            ''');
        await customStatement('''
              DELETE FROM carga_diaria WHERE id NOT IN (
                SELECT MAX(id) FROM carga_diaria
                GROUP BY reparto_id, producto_id, dia_semana, semana
              )
            ''');

        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_entregas_unique ON entregas(cliente_id, reparto_id, producto_id, semana, dia_semana)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_pagos_unique ON pagos(cliente_id, reparto_id, semana, dia_semana)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_carga_diaria_unique ON carga_diaria(reparto_id, producto_id, dia_semana, semana)',
        );
      }
      if (from < 47) {
        // P0.5: updated_at + dirty on business tables for cloud-restore
        // freshness checks. _ensureColumn is PRAGMA-guarded so it's
        // safe on already-migrated devices.
        await _ensureColumn(
          'entregas',
          'updated_at',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn('entregas', 'dirty', 'INTEGER NOT NULL DEFAULT 0');
        await _ensureColumn(
          'pagos',
          'updated_at',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn('pagos', 'dirty', 'INTEGER NOT NULL DEFAULT 0');
        await _ensureColumn(
          'carga_diaria',
          'updated_at',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn(
          'carga_diaria',
          'dirty',
          'INTEGER NOT NULL DEFAULT 0',
        );

        // P0.6: cuentas_local table for profile data in Drift instead
        // of cloud-direct.
        await customStatement('''
              CREATE TABLE IF NOT EXISTS cuentas_local (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL UNIQUE,
                email TEXT NOT NULL DEFAULT '',
                nombre TEXT NOT NULL DEFAULT '',
                telefono TEXT NOT NULL DEFAULT '',
                updated_at INTEGER NOT NULL DEFAULT 0,
                dirty INTEGER NOT NULL DEFAULT 0
              )
            ''');
      }
      if (from < 48) {
        // Optional auto-mark Listo when a payment method is tapped.
        await _ensureColumn(
          'user_settings',
          'auto_listo_on_pago',
          'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 49) {
        // One-day "borrow" override for cliente day. See onCreate note.
        await _ensureColumn('clientes', 'temp_dia_semana', 'INTEGER');
        await _ensureColumn('clientes', 'temp_dia_date', 'TEXT');
      }
      if (from < 50) {
        // Profile photo: local cached file + synced cloud URL.
        await _ensureColumn(
          'cuentas_local',
          'foto_path',
          "TEXT NOT NULL DEFAULT ''",
        );
        await _ensureColumn(
          'cuentas_local',
          'foto_url',
          "TEXT NOT NULL DEFAULT ''",
        );
      }
      if (from < 51) {
        // Profile photo sync metadata. Local-only; not mirrored to Supabase.
        await _ensureColumn(
          'cuentas_local',
          'foto_dirty',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn(
          'cuentas_local',
          'foto_upload_pending_path',
          "TEXT NOT NULL DEFAULT ''",
        );
      }
      if (from < 53) {
        // Phase 2 / v53: per-section dirty counters on user_settings.
        // Each section (secure: AFIP+MP, prefs: everything else) can be
        // pushed independently so a preference toggle no longer
        // overwrites a sibling device's AFIP/MP edit. Backfill copies
        // the legacy `settings_dirty` value into BOTH new counters —
        // conservative: if we don't know which section was dirty, push
        // both, and the trigger / per-section partial upsert sort it
        // out at the cloud.
        await _ensureColumn(
          'user_settings',
          'settings_dirty_secure',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn(
          'user_settings',
          'settings_dirty_prefs',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'UPDATE user_settings SET '
          'settings_dirty_secure = settings_dirty, '
          'settings_dirty_prefs = settings_dirty '
          'WHERE id = 1',
        );
      }
      if (from < 54) {
        // Phase 3 / v54: tombstones_seen — local idempotency record so
        // pulled cloud tombstones aren't re-applied on every realtime
        // tick. The table is purely additive; no data backfill needed.
        // First-time tombstone pull on this device will populate it as
        // rows arrive.
        await customStatement('''
              CREATE TABLE IF NOT EXISTS tombstones_seen (
                user_id TEXT NOT NULL,
                table_name TEXT NOT NULL,
                row_id INTEGER NOT NULL,
                deleted_at INTEGER NOT NULL,
                PRIMARY KEY (user_id, table_name, row_id)
              )
            ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tombstones_seen_user_deleted_at '
          'ON tombstones_seen(user_id, deleted_at)',
        );
      }
      if (from < 55) {
        // Phase 2 remainder / v55: extend the dirty + updated_at pattern
        // to the 7 tables that previously full-uploaded every sync.
        // Backfills dirty=1 + updated_at=now() for existing rows so the
        // first post-upgrade push uploads everything once (mirroring
        // pre-v55 behavior), then the cloud trigger arbitrates and the
        // steady state moves to per-edit pushes only.
        //
        // `WHERE updated_at = 0` keeps the backfill idempotent — if any
        // row already has a non-zero updated_at from an earlier partial
        // migration, leave it alone.
        for (final t in const [
          'productos',
          'repartos',
          'producto_precios',
          'stock_notif_settings',
          'habitual_product_settings',
          'facturas',
          'etiqueta_colors',
        ]) {
          await _ensureColumn(t, 'updated_at', 'INTEGER NOT NULL DEFAULT 0');
          await _ensureColumn(t, 'dirty', 'INTEGER NOT NULL DEFAULT 0');
          final nowMs = LogicalClock.nextMs();
          await customStatement(
            'UPDATE $t SET dirty = 1, updated_at = ? WHERE updated_at = 0',
            [nowMs],
          );
        }
      }
      if (from < 56) {
        // Phase 6 / v56: active recorrido cross-device sync columns.
        // Idempotent _ensureColumn — adds nothing on fresh installs where
        // onCreate already added them, adds the missing columns on
        // upgrades. Existing deployments default to sync_recorrido_enabled = 0
        // so behaviour is unchanged until the user opts in.
        await _ensureColumn(
          'user_settings',
          'settings_dirty_recorrido',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn(
          'user_settings',
          'active_recorridos_json_prev',
          "TEXT NOT NULL DEFAULT ''",
        );
        await _ensureColumn(
          'user_settings',
          'sync_recorrido_enabled',
          'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 57) {
        // Phase 4 / v57: uid column on every business table + feature
        // flag. NO local backfill of existing rows — uids propagate
        // FROM cloud into local on the next pull (cloud-side gen_random_uuid
        // backfill is part of the v55 cloud SQL companion), and new
        // local inserts get a UUID v7 stamped lazily at push time. The
        // index on each uid column is non-unique on purpose: a UNIQUE
        // index here would explode if cloud and local end up disagreeing
        // on a uid for the same id (which can happen during the
        // propagation window before the flag is flipped).
        for (final t in const [
          'productos',
          'repartos',
          'clientes',
          'cliente_productos',
          'carga_diaria',
          'entregas',
          'pagos',
          'resumenes',
          'producto_precios',
          'stock_notif_settings',
          'habitual_product_settings',
          'facturas',
          'etiqueta_colors',
        ]) {
          await _ensureColumn(t, 'uid', 'TEXT');
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_${t}_uid ON $t(uid)',
          );
        }
        await _ensureColumn(
          'user_settings',
          'sync_uid_enabled',
          'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 58) {
        // v58 — recover from a pre-existing onCreate gap that left
        // doc_nro_cache missing on fresh installs. Old upgrade paths
        // (from < 31 block above) already add the column for existing
        // installs; this defensive _ensureColumn covers any device
        // whose onCreate ran without the column AND is now upgrading
        // to v58+. No-op when the column already exists.
        await _ensureColumn(
          'clientes',
          'doc_nro_cache',
          "TEXT NOT NULL DEFAULT '{}'",
        );
      }
      if (from < 59) {
        // v59 — field-aware cliente dirty tracking. A single row-level dirty
        // flag made unrelated local edits (orden / no-op sheet saves /
        // legacy balance stamps) upload the entire stale cliente row and
        // overwrite fresh web edits. dirty_fields records the exact cloud
        // columns locally changed so SyncService can merge per field.
        await _ensureColumn(
          'clientes',
          'dirty_fields',
          "TEXT NOT NULL DEFAULT ''",
        );
        await customStatement('''
              CREATE TABLE IF NOT EXISTS clientes_sync_conflicts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cliente_id INTEGER NOT NULL,
                detected_at INTEGER NOT NULL,
                reason TEXT NOT NULL,
                local_json TEXT NOT NULL,
                cloud_json TEXT NOT NULL
              )
            ''');
      }
      if (from < 60) {
        await customStatement(
          'ALTER TABLE clientes ADD COLUMN marked_semana TEXT;',
        );
      }
      if (from < 61) {
        await _ensureColumn(
          'user_settings',
          'vista_rapida_fields',
          "TEXT NOT NULL DEFAULT 'saldo,frecuencia,etiquetas,notas'",
        );
      }
      if (from < 62) {
        await _ensureColumn('resumenes', 'start_millis', 'INTEGER');
        await _ensureColumn('resumenes', 'end_millis', 'INTEGER');
      }
      if (from < 63) {
        await _ensureColumn('productos', 'pack_size', 'INTEGER');
      }
      if (from < 64) {
        // v64: heal a bad pack_size column that landed on some dev
        // devices as `INTEGER NOT NULL DEFAULT 1`. The v63 migration
        // creates it nullable, but `_ensureColumn` only checks column
        // existence by NAME — so once a wrong-flavor column is
        // present, every later run skips the ALTER and the NOT NULL
        // constraint sticks forever.
        //
        // Symptom on the affected device: SqliteException(1299) when
        // toggling pack mode OFF (setProductoPackSize calls UPDATE
        // pack_size = NULL → constraint fires).
        //
        // Fix: introspect the column. If notnull=0, no-op. Otherwise
        // do the standard SQLite "rename + recreate + copy + drop"
        // dance to swap in a nullable column. Legitimate pack sizes
        // (≥2) are preserved; the buggy default value 1 is mapped to
        // NULL (= "not a pack"), matching the rest of the app's
        // semantics.
        await _healProductosPackSizeNullable();
      }
      if (from < 65) {
        // v65: subscription_paid flag on user_settings. Cloud-driven —
        // the admin flips this in Supabase when the sodero pays the
        // monthly fee. Default 0 (unpaid) so the reminder is the
        // out-of-the-box state until the admin marks them paid.
        await _ensureColumn(
          'user_settings',
          'subscription_paid',
          'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 66) {
        await customStatement(
          "ALTER TABLE resumenes ADD COLUMN sessions_json TEXT NOT NULL DEFAULT '[]'",
        );
        await customStatement('''
          UPDATE resumenes
          SET sessions_json = '[{"startMillis":' || start_millis || ',"endMillis":' || end_millis || '}]'
          WHERE sessions_json = '[]'
            AND start_millis IS NOT NULL
            AND end_millis IS NOT NULL
        ''');
      }
      if (from < 67) {
        await customStatement(
          "ALTER TABLE entregas ADD COLUMN fecha TEXT NOT NULL DEFAULT ''",
        );
        await customStatement(
          "ALTER TABLE pagos ADD COLUMN fecha TEXT NOT NULL DEFAULT ''",
        );
        await customStatement(
          "ALTER TABLE carga_diaria ADD COLUMN fecha TEXT NOT NULL DEFAULT ''",
        );
        await _createCcAuditLogSchema();
        await _backfillFechaColumns();
      }
      if (from < 52) {
        // v52: extend the v47 dirty/updated_at pattern to clientes,
        // cliente_productos, and resumenes. See onCreate above for the
        // full rationale.
        await _ensureColumn(
          'clientes',
          'updated_at',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn('clientes', 'dirty', 'INTEGER NOT NULL DEFAULT 0');
        await _ensureColumn(
          'cliente_productos',
          'updated_at',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn(
          'cliente_productos',
          'dirty',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn(
          'resumenes',
          'updated_at',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn('resumenes', 'dirty', 'INTEGER NOT NULL DEFAULT 0');
        // F5: stamp every existing row dirty=1 with updated_at=now so
        // pre-v52 offline edits aren't silently overwritten by the next
        // cloud pull. Without this, migrated rows are dirty=0 and the
        // restore helpers would happily clobber them with cloud's value
        // even when local had unpushed work.
        //
        // The first post-upgrade push uploads every cliente /
        // cliente_producto / resumen ONCE (mirroring pre-v52 behavior
        // for a single cycle). Cloud's reject_stale_update trigger then
        // arbitrates: rows where cloud is newer than upgrade time get
        // rejected and pulled back via the post-push confirmation; rows
        // where mobile is newer (including offline edits) catch cloud
        // up. After this one cycle, dirty=0 everywhere and the steady-
        // state v52 contract resumes.
        //
        // `WHERE updated_at = 0` makes the migration idempotent — won't
        // re-stamp rows that already have a real updated_at on a
        // partially-migrated DB.
        final nowMs = LogicalClock.nextMs();
        await customStatement(
          'UPDATE clientes SET dirty = 1, updated_at = ? WHERE updated_at = 0',
          [nowMs],
        );
        await customStatement(
          'UPDATE cliente_productos SET dirty = 1, updated_at = ? WHERE updated_at = 0',
          [nowMs],
        );
        await customStatement(
          'UPDATE resumenes SET dirty = 1, updated_at = ? WHERE updated_at = 0',
          [nowMs],
        );
      }
      if (from < 68) {
        await _runWave3IsoWeekMigration();
      }
      if (from < 69) {
        // PRAGMA-guarded so re-runs after a rolled-back later-migration
        // don't crash with "duplicate column name" — the v70 messaging
        // migration's first hotfix-cycle could leave a device with the
        // column already present but its recorded schemaVersion not
        // advanced past 68.
        await _ensureColumn(
          'user_settings',
          'last_cc_expiry_recompute_date',
          "TEXT NOT NULL DEFAULT ''",
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_entregas_fecha ON entregas(fecha)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos(fecha)',
        );
      }
      if (from < 70) {
        await _ensureMessagingSchema();
      }
      if (from < 71) {
        await _ensureColumn(
          'user_settings',
          'admin_message_banner_enabled',
          'INTEGER NOT NULL DEFAULT 1',
        );
      }
      if (from < 72) {
        await _ensureColumn(
          'productos',
          'precio_dirty',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn(
          'carga_diaria',
          'cantidad_synced',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'UPDATE carga_diaria SET cantidad_synced = cantidad WHERE dirty = 0',
        );
      }
      if (from < 73) {
        await customStatement(
          'UPDATE carga_diaria SET cantidad_synced = cantidad '
          'WHERE cantidad_synced = 0 AND cantidad > 0',
        );
        await _ensureColumn('carga_diaria', 'pending_push_id', 'TEXT');
      }
      if (from < 74) {
        await _ensureColumn('productos', 'precio_mayorista', 'REAL');
        await _ensureColumn(
          'productos',
          'precio_mayorista_dirty',
          'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 76) {
        // v75 poisoned precio_mayorista with the venta price. Per user
        // direction: productos.precio is the mayorista; the new
        // precio_mayorista column is unused. NULL it out wholesale.
        await customStatement('UPDATE productos SET precio_mayorista = NULL');
      }
      if (from < 77) {
        await _ensurePerformanceIndexes();
      }
      if (from < 78) {
        // Per-column dirty flag for pack_size (mirrors precio_dirty) so a local
        // pack edit survives a concurrent cloud pull instead of being reverted.
        await _ensureColumn(
          'productos',
          'pack_size_dirty',
          'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 79) {
        // v79: split the secure user_settings intent into MP and AFIP local
        // counters. Blanks are only pushed for the section the user actually
        // edited; unhydrated blanks still cannot wipe cloud values.
        await _ensureColumn(
          'user_settings',
          'settings_dirty_mp',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _ensureColumn(
          'user_settings',
          'settings_dirty_afip',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'UPDATE user_settings SET '
          'settings_dirty_mp = settings_dirty_secure, '
          'settings_dirty_afip = settings_dirty_secure '
          'WHERE id = 1',
        );
      }
      if (from < 80) {
        // P0-2 / v80 (audit #2): per-device AUTOINCREMENT id ranges.
        // Existing rows keep their ids (history shared across devices
        // stays aligned); only NEW allocations move into this device's
        // own random range so offline creations can never collide.
        await seedDeviceIdRanges();
      }
      if (from < 81) {
        // P1-8 / v81 (audit #8): resumenes natural-key uniqueness. See
        // dedupeAndIndexResumenes — archives duplicate (reparto, fecha,
        // dia) rows keeping the newest, then adds the UNIQUE index that
        // makes get-or-create and the cloud pull collision-proof.
        await dedupeAndIndexResumenes();
      }
      if (from < 82) {
        // P1-9 / v82 (audit #9): freeze legacy zero-snapshot entregas at
        // today's effective price. See backfillZeroSnapshotPrecios.
        // Fresh installs skip this — onCreate has no legacy rows.
        await backfillZeroSnapshotPrecios();
      }
      if (from < 83) {
        // v83: resumenes now converge by natural key, so their local id can
        // differ from cloud's id. Keep the NK in pending_deletions so an
        // offline resumen delete is not resurrected by a later pull.
        await _ensureColumn('pending_deletions', 'key_json', 'TEXT');
      }
      if (from < 84) {
        // v84: user preference for whether product carga is counted as gastos.
        // Default ON preserves existing behavior for every current sodero.
        await _ensureColumn(
          'user_settings',
          'carga_gastos_enabled',
          'INTEGER NOT NULL DEFAULT 1',
        );
      }
      if (from < 85) {
        // v85 — «Instancias»: per-reparto parallel day-views registry
        // (see lib/utils/recorrido_merge.dart for the sync merge).
        await _ensureColumn(
          'user_settings',
          'instances_json',
          "TEXT NOT NULL DEFAULT '[]'",
        );
        // Recorrido-state sync is now ON for everyone (the feature's
        // cross-device visibility depends on it, and push/pull moved to a
        // per-entry merge that cannot clobber a sibling device). The cloud
        // column has defaulted to 1 since the v56 cloud follow-up and the
        // pull copies it down — but a device upgrading OFFLINE would sit
        // at the old local 0 until its first pull, leaving its recorrido
        // edits unshared. Self-heal idempotently.
        await customStatement(
          'UPDATE user_settings SET sync_recorrido_enabled = 1 WHERE id = 1',
        );
      }
    },
  );

  /// P1-9 / v82 (pre-release audit #9): stamp a price snapshot onto legacy
  /// entregas that have `entregado > 0` but `precio_unitario = 0`.
  ///
  /// The cuenta-corriente recompute (local SQL + the mirrored cloud
  /// function) values zero-snapshot rows through a CURRENT-price fallback
  /// chain — so editing a producto price today silently re-valued YEARS of
  /// history (retroactive CC warping). New writes always stamp a snapshot;
  /// this one-time backfill freezes the legacy rows at exactly the value
  /// the fallback chain produces today, so CC is unchanged by construction
  /// and future price edits can no longer touch history.
  ///
  /// Deliberately does NOT bump updated_at or dirty: the same backfill
  /// runs cloud-side (P1-9 SQL phase, which DOES stamp updated_at=now()),
  /// so every device converges through the normal pull instead of a mass
  /// local push. The fallback chain stays in the CC SQL afterwards as
  /// belt-and-suspenders for any row this migration couldn't price.
  ///
  /// Returns the number of rows stamped.
  @visibleForTesting
  Future<int> backfillZeroSnapshotPrecios() async {
    // Mirrors recalcCuentaCorrienteForCliente's chain EXACTLY:
    //   1. the cliente's assigned price tier (cliente_productos →
    //      producto_precios),
    //   2. the producto's first price tier (lowest orden),
    //   3. productos.precio.
    const chain =
        'COALESCE('
        '(SELECT pp.precio FROM producto_precios pp '
        'INNER JOIN cliente_productos cp ON cp.precio_tipo_id = pp.id '
        'WHERE cp.cliente_id = entregas.cliente_id '
        'AND cp.producto_id = entregas.producto_id LIMIT 1), '
        '(SELECT pp2.precio FROM producto_precios pp2 '
        'WHERE pp2.producto_id = entregas.producto_id '
        'ORDER BY pp2.orden ASC LIMIT 1), '
        '(SELECT pr.precio FROM productos pr '
        'WHERE pr.id = entregas.producto_id), '
        '0)';
    return customUpdate(
      'UPDATE entregas SET precio_unitario = $chain '
      'WHERE entregado > 0 AND precio_unitario = 0 AND $chain > 0',
      updates: {entregas},
      updateKind: UpdateKind.update,
    );
  }

  /// P1-8 / v81 (pre-release audit #8): one resumen per (reparto, fecha,
  /// dia_semana) — enforced, not assumed.
  ///
  /// getOrCreateTodayResumen used to be SELECT-then-INSERT with no unique
  /// index anywhere (local or cloud only had UNIQUE(user_id, id)), so a
  /// double-tap race or two devices closing the same day produced TWO
  /// resumen rows — and web finanzas summed both (double-counted gastos /
  /// sueldo).
  ///
  /// Losers (older updated_at, then lower id) are ARCHIVED into
  /// resumenes_archive before deletion — same never-destroy-data pattern
  /// as the v46 entregas dedupe — then the UNIQUE index lands. Used by
  /// BOTH onCreate (no-op dedupe, creates index) and the v81 onUpgrade.
  @visibleForTesting
  Future<void> dedupeAndIndexResumenes() async {
    await transaction(() async {
      await customStatement('''
            CREATE TABLE IF NOT EXISTS resumenes_archive (
              id INTEGER,
              reparto_id INTEGER,
              fecha TEXT,
              semana TEXT,
              dia_semana INTEGER,
              duracion_segundos INTEGER,
              efectivo REAL,
              transferencia REAL,
              cuenta_corriente REAL,
              gastos REAL,
              sueldo_neto REAL,
              productos_json TEXT,
              gastos_json TEXT,
              archived_at INTEGER,
              archived_reason TEXT
            )
          ''');
      const loserPredicate =
          'EXISTS (SELECT 1 FROM resumenes b '
          'WHERE b.reparto_id = resumenes.reparto_id '
          'AND b.fecha = resumenes.fecha '
          'AND b.dia_semana = resumenes.dia_semana '
          'AND (b.updated_at > resumenes.updated_at '
          'OR (b.updated_at = resumenes.updated_at AND b.id > resumenes.id)))';
      await customStatement(
        'INSERT INTO resumenes_archive '
        '(id, reparto_id, fecha, semana, dia_semana, duracion_segundos, '
        'efectivo, transferencia, cuenta_corriente, gastos, sueldo_neto, '
        'productos_json, gastos_json, archived_at, archived_reason) '
        'SELECT id, reparto_id, fecha, semana, dia_semana, '
        'duracion_segundos, efectivo, transferencia, cuenta_corriente, '
        'gastos, sueldo_neto, productos_json, gastos_json, ?, '
        "'v81_nk_dedupe' FROM resumenes WHERE $loserPredicate",
        [DateTime.now().millisecondsSinceEpoch],
      );
      await customStatement('DELETE FROM resumenes WHERE $loserPredicate');
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS resumenes_nk '
        'ON resumenes(reparto_id, fecha, dia_semana)',
      );
    });
  }

  /// P0-2 / v80 (pre-release audit #2): collision-proof AUTOINCREMENT.
  ///
  /// Local ids are plain SQLite AUTOINCREMENT and the cloud upsert resolves
  /// on UNIQUE(user_id, id) — so two devices on one account creating rows
  /// OFFLINE could mint the same id for different real entities (cliente
  /// #100 on phone A vs cliente #100 on phone B). The second push silently
  /// replaced the first (id-keyed tables) or hit a 23505 unique violation
  /// (NK tables). Child rows (entregas.cliente_id, …) made it worse:
  /// integer FKs can't tell two same-id parents apart — which is also why
  /// the dormant Phase-4 uid flag alone can't close this (uids
  /// disambiguate parents, not the children's references to them).
  ///
  /// Fix at the SOURCE: each device allocates new ids inside its own
  /// random multi-billion range, making ids effectively globally unique
  /// across an account's devices — the collision never exists, for parents
  /// AND children, with no cloud migration and no pull-path changes.
  ///
  /// Mechanics: base = (1 + r) · 2³³ with r ∈ [0, 2¹⁹) — ~524k slots
  /// spaced ~8.6 billion apart, max ≈ 2⁵² (safe for cloud BIGINT and for
  /// Dart-web's 2⁵³ exact-integer limit; plain multiplication because
  /// dart2js shifts truncate at 32 bits). Each business table's
  /// sqlite_sequence is bumped to the base only while its seq is below 2³³
  /// — idempotent, so an already-seeded device never re-rolls its range.
  @visibleForTesting
  Future<void> seedDeviceIdRanges() async {
    const slotSize = 8589934592; // 2^33
    final base = (1 + Random.secure().nextInt(1 << 19)) * slotSize;
    // Cloud-synced business tables only — local-only AUTOINCREMENT tables
    // (cuentas_local, pending_deletions, audit logs…) can't collide
    // cross-device and keep their small ids.
    const tables = [
      'productos',
      'repartos',
      'clientes',
      'cliente_productos',
      'carga_diaria',
      'entregas',
      'pagos',
      'resumenes',
      'producto_precios',
      'stock_notif_settings',
      'habitual_product_settings',
      'facturas',
      'etiqueta_colors',
    ];
    await transaction(() async {
      for (final t in tables) {
        await customStatement(
          'UPDATE sqlite_sequence SET seq = ? WHERE name = ? AND seq < ?',
          [base, t, slotSize],
        );
        // Tables that never allocated a row have no sqlite_sequence entry
        // yet — create one at the base so their first insert lands inside
        // the device's range.
        await customStatement(
          'INSERT INTO sqlite_sequence (name, seq) '
          'SELECT ?, ? WHERE NOT EXISTS '
          '(SELECT 1 FROM sqlite_sequence WHERE name = ?)',
          [t, base, t],
        );
      }
    });
  }

  Future<void> _ensureMessagingSchema() async {
    // Drift snake-cases the class name `AppNotifications` → table
    // `app_notifications`. The migration was originally drafted against
    // the wrong name "notifications" which made fresh schema upgrades
    // fail on every device with "no such table: notifications".
    await _ensureColumn('app_notifications', 'message_id', 'INTEGER');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_app_notifications_message_id '
      'ON app_notifications(message_id) WHERE message_id IS NOT NULL',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS dismissed_admin_messages ('
      '  message_id INTEGER PRIMARY KEY,'
      '  dismissed_at INTEGER NOT NULL'
      ')',
    );
  }

  Future<void> _addFechaColumns() async {
    await customStatement(
      "ALTER TABLE entregas ADD COLUMN fecha TEXT NOT NULL DEFAULT ''",
    );
    await customStatement(
      "ALTER TABLE pagos ADD COLUMN fecha TEXT NOT NULL DEFAULT ''",
    );
    await customStatement(
      "ALTER TABLE carga_diaria ADD COLUMN fecha TEXT NOT NULL DEFAULT ''",
    );
  }

  Future<void> _createCcAuditLogSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cc_audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT,
        user_id TEXT,
        cliente_id INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        trigger_event TEXT NOT NULL,
        before_cc REAL,
        after_cc REAL,
        delta REAL,
        source_table TEXT,
        source_row_id INTEGER,
        notes TEXT,
        dirty INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_cc_audit_uid '
      'ON cc_audit_log(uid) WHERE uid IS NOT NULL',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cc_audit_cliente_time '
      'ON cc_audit_log(cliente_id, occurred_at DESC)',
    );
  }

  Future<void> _createMigrationAuditLogSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS migration_audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        occurred_at INTEGER NOT NULL,
        migration TEXT NOT NULL,
        severity TEXT NOT NULL,
        details TEXT
      )
    ''');
  }

  DateTime? _parseStrictIsoDate(String fecha) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(fecha);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  Future<void> _runWave3IsoWeekMigration() async {
    await transaction(() async {
      await _createMigrationAuditLogSchema();
      await _rekeyIsoWeekTable(
        table: 'entregas',
        naturalKeyCols: const ['cliente_id', 'reparto_id', 'producto_id'],
        payloadCols: const ['entregado', 'devuelto'],
        collisionSeverity: 'WARN_ENTREGAS_COLLISION_SKIPPED',
      );
      await _rekeyIsoWeekTable(
        table: 'pagos',
        naturalKeyCols: const ['cliente_id', 'reparto_id'],
        payloadCols: const ['metodo_pago', 'monto'],
        collisionSeverity: 'WARN_PAGOS_COLLISION_SKIPPED',
      );
      await _rekeyIsoWeekTable(
        table: 'carga_diaria',
        naturalKeyCols: const ['reparto_id', 'producto_id'],
        payloadCols: const ['cantidad', 'remanente'],
        collisionSeverity: 'WARN_CARGA_COLLISION_SKIPPED',
      );
      await _rekeyResumenesIsoWeek();
    });
  }

  Future<void> _rekeyIsoWeekTable({
    required String table,
    required List<String> naturalKeyCols,
    required List<String> payloadCols,
    required String collisionSeverity,
  }) async {
    final selectedCols = [
      'id',
      'semana',
      'dia_semana',
      'fecha',
      ...naturalKeyCols,
      ...payloadCols,
    ].join(', ');
    final rows = await customSelect(
      "SELECT $selectedCols FROM $table WHERE fecha != ''",
    ).get();

    for (final row in rows) {
      final fecha = row.read<String>('fecha');
      final parsedFecha = _parseStrictIsoDate(fecha);
      if (parsedFecha == null) continue;

      final newSemana = argentinaWeekString(at: parsedFecha);
      final oldSemana = row.read<String>('semana');
      if (newSemana == oldSemana) continue;

      final collisionRows = await customSelect(
        'SELECT id, ${payloadCols.join(', ')} '
        'FROM $table WHERE semana = ? AND dia_semana = ? '
        '${naturalKeyCols.map((c) => 'AND $c = ?').join(' ')} '
        'AND id != ? LIMIT 1',
        variables: [
          Variable.withString(newSemana),
          Variable.withInt(row.read<int>('dia_semana')),
          ...naturalKeyCols.map((c) => Variable.withInt(row.read<int>(c))),
          Variable.withInt(row.read<int>('id')),
        ],
      ).get();

      if (collisionRows.isNotEmpty) {
        final details = <String, Object?>{
          'table': table,
          'rekey_id': row.read<int>('id'),
          'colliding_with': collisionRows.first.read<int>('id'),
          'dia_semana': row.read<int>('dia_semana'),
          'old_semana': oldSemana,
          'new_semana': newSemana,
        };
        for (final col in naturalKeyCols) {
          details[col] = row.data[col];
        }
        for (final col in payloadCols) {
          details['rekey_$col'] = row.data[col];
          details['colliding_$col'] = collisionRows.first.data[col];
        }
        await customStatement(
          'INSERT INTO migration_audit_log '
          '(occurred_at, migration, severity, details) '
          'VALUES (?, ?, ?, ?)',
          [
            DateTime.now().millisecondsSinceEpoch,
            'wave3_iso_week',
            collisionSeverity,
            jsonEncode(details),
          ],
        );
        continue;
      }

      await customStatement(
        'UPDATE $table SET semana = ?, updated_at = ? WHERE id = ?',
        [newSemana, DateTime.now().millisecondsSinceEpoch, row.read<int>('id')],
      );
    }
  }

  Future<void> _rekeyResumenesIsoWeek() async {
    final rows = await customSelect(
      "SELECT id, semana, fecha FROM resumenes WHERE fecha != ''",
    ).get();
    for (final row in rows) {
      final parsedFecha = _parseStrictIsoDate(row.read<String>('fecha'));
      if (parsedFecha == null) continue;
      final newSemana = argentinaWeekString(at: parsedFecha);
      if (newSemana == row.read<String>('semana')) continue;
      await customStatement(
        'UPDATE resumenes SET semana = ?, updated_at = ? WHERE id = ?',
        [newSemana, DateTime.now().millisecondsSinceEpoch, row.read<int>('id')],
      );
    }
  }

  Future<void> _backfillFechaColumns() async {
    for (final table in const ['entregas', 'pagos', 'carga_diaria']) {
      final rows = await customSelect(
        'SELECT id, semana, dia_semana FROM $table WHERE fecha = ?',
        variables: [Variable.withString('')],
      ).get();
      for (final r in rows) {
        final fecha = fechaFromDisplayedSemana(
          r.read<String>('semana'),
          r.read<int>('dia_semana'),
        );
        if (fecha.isEmpty) continue;
        await customStatement('UPDATE $table SET fecha = ? WHERE id = ?', [
          fecha,
          r.read<int>('id'),
        ]);
      }
    }
  }

  /// PRAGMA-guarded ALTER TABLE ADD COLUMN. Safe to call on devices where
  /// the column may already exist (e.g. partially-migrated DBs from v33-v45
  /// shipped builds before this revert). Used by the v46 migration block.
  Future<void> _ensureColumn(String table, String column, String type) async {
    final cols = await customSelect("PRAGMA table_info($table)").get();
    final exists = cols.any((r) => r.read<String>('name') == column);
    if (!exists) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _ensurePerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_clientes_reparto_dia ON clientes(reparto_id, dia_semana)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_clientes_reparto_dirty ON clientes(reparto_id, dirty)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cliente_productos_cliente_dirty ON cliente_productos(cliente_id, dirty)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entregas_reparto_day ON entregas(reparto_id, semana, dia_semana)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entregas_reparto_dirty ON entregas(reparto_id, dirty)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pagos_reparto_day ON pagos(reparto_id, semana, dia_semana)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pagos_reparto_dirty ON pagos(reparto_id, dirty)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_carga_reparto_dirty ON carga_diaria(reparto_id, dirty)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_resumenes_reparto_dirty ON resumenes(reparto_id, dirty)',
    );
  }

  /// v64 migration helper. See the call site in `onUpgrade` for the
  /// background. SQLite cannot DROP a NOT NULL constraint in-place, so
  /// the only fix on an affected device is to rebuild the table.
  Future<void> _healProductosPackSizeNullable() async {
    final cols = await customSelect('PRAGMA table_info(productos)').get();
    final pack = cols
        .where((r) => r.read<String>('name') == 'pack_size')
        .firstOrNull;
    if (pack == null) {
      // Column doesn't exist — onCreate or onUpgrade(<63) should have
      // added it. Nothing to heal.
      return;
    }
    final notNull = pack.read<int>('notnull') == 1;
    if (!notNull) {
      // Column already nullable — nothing to do.
      return;
    }
    // The rebuild is non-destructive — all columns in the canonical
    // schema are preserved by name. Any column outside the canonical
    // set would silently disappear, but there shouldn't be any.
    await transaction(() async {
      await customStatement(
        'ALTER TABLE productos RENAME TO productos_v64_old',
      );
      await customStatement('''
        CREATE TABLE productos (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          reparto_id INTEGER,
          nombre TEXT NOT NULL,
          orden INTEGER NOT NULL DEFAULT 0,
          precio REAL NOT NULL DEFAULT 0.0,
          deleted INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          dirty INTEGER NOT NULL DEFAULT 0,
          uid TEXT,
          pack_size INTEGER
        )
      ''');
      // Map values back. Pack sizes < 2 become NULL (treat the bad
      // default value 1 as "no pack" — matches setProductoPackSize's
      // clamping logic).
      await customStatement('''
        INSERT INTO productos
          (id, reparto_id, nombre, orden, precio, deleted,
           updated_at, dirty, uid, pack_size)
        SELECT
          id, reparto_id, nombre, orden, precio, deleted,
          updated_at, dirty, uid,
          CASE WHEN pack_size >= 2 THEN pack_size ELSE NULL END
        FROM productos_v64_old
      ''');
      await customStatement('DROP TABLE productos_v64_old');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_productos_uid ON productos(uid)',
      );
    });
  }

  /// Atomically recompute `clientes.cuenta_corriente` for one cliente from
  /// the full historial: total paid (excluding non-payment metodos) minus
  /// total owed (qty × snapshot price, falling back to the current effective
  /// price for legacy zero-snapshot rows). Pre-caches effective prices once
  /// per distinct legacy producto so a 50-entrega cliente with 3 distinct
  /// legacy products triggers 3 price lookups, not 50.
  ///
  /// MUST be called inside a transaction by setEntrega/setPago — never from
  /// screen code as a standalone refresh, that's the lag pattern v37 fell
  /// into.
  ///
  /// Phase 16: `markDirty` defaults to **false**. Stamping the whole cliente
  /// row dirty for a derived-field recompute caused the snap-back bug —
  /// mobile would push the entire cliente row (including a stale `direccion`
  /// from the prior cloud pull) with a fresh `updated_at`, and the cloud's
  /// `reject_stale_update` trigger accepted it, overwriting web admin's
  /// recent address edits.
  ///
  /// Cloud now owns `cuenta_corriente` authoritatively via the v59
  /// `recompute_cliente_cuenta_corriente` trigger on entregas + pagos.
  /// The local UPDATE below still keeps mobile's UI accurate
  /// immediately; the next cloud pull harmonises mobile with cloud's
  /// (slightly different for legacy zero-precio entregas) value.
  ///
  /// Callers that *do* want to push the recomputed value (e.g. one-shot
  /// migrations) can pass `markDirty: true` explicitly — but the default
  /// path no longer pushes.
  Future<void> recalcCuentaCorrienteForCliente(
    int clienteId, {
    bool markDirty = false,
  }) async {
    final today = argTodayFecha();

    await customStatement(
      '''
      UPDATE clientes
      SET cuenta_corriente =
        COALESCE((
          SELECT SUM(p.monto)
          FROM pagos p
          WHERE p.cliente_id = ?
            AND p.metodo_pago NOT IN ('no_pago','no_compro','ausente','saltado')
            AND p.fecha != ''
            AND p.fecha <= ?
        ), 0.0) -
        COALESCE((
          SELECT SUM(e.entregado * COALESCE(
            NULLIF(e.precio_unitario, 0),
            (SELECT pp.precio FROM producto_precios pp
               INNER JOIN cliente_productos cp ON cp.precio_tipo_id = pp.id
              WHERE cp.cliente_id = e.cliente_id
                AND cp.producto_id = e.producto_id
              LIMIT 1),
            (SELECT pp2.precio FROM producto_precios pp2
              WHERE pp2.producto_id = e.producto_id
              ORDER BY pp2.orden ASC LIMIT 1),
            (SELECT pr.precio FROM productos pr WHERE pr.id = e.producto_id),
            0
          ))
          FROM entregas e
          WHERE e.cliente_id = ?
            AND e.entregado > 0
            AND e.fecha != ''
            AND e.fecha <= ?
        ), 0.0)
      WHERE id = ?
      ''',
      [clienteId, today, clienteId, today, clienteId],
    );
    // Phase 16: by default, do NOT stamp the cliente row dirty.
    // Cloud's `recompute_cliente_cuenta_corriente` trigger updates
    // cuenta_corriente authoritatively from entregas/pagos, so the
    // mobile push of a derived value is redundant — and was causing
    // the snap-back bug (mobile re-uploading the full cliente row
    // with stale direccion + fresh timestamp, beating web's edit).
    if (markDirty) {
      await _stampClienteDirty(clienteId, fields: const {'cuenta_corriente'});
    }
  }

  /// Bulk-recompute cuenta_corriente for every cliente belonging to [userId]
  /// in a single SQL statement. Used after a fresh restoreFromCloud where the
  /// per-cliente Dart loop would issue O(N×3) round-trips to local SQLite.
  ///
  /// Mirrors recalcCuentaCorrienteForCliente exactly:
  ///   • totalOwed   = SUM(entregado * effective_price)  for entregas where entregado > 0
  ///   • totalPaid   = SUM(monto)                        for pagos where metodo_pago NOT IN
  ///                                                       ('no_pago','no_compro','ausente','saltado')
  ///   • effective_price priority chain (= getEffectivePrice):
  ///       1. e.precio_unitario when > 0
  ///       2. producto_precios.precio for cliente_productos.precio_tipo_id (if assigned)
  ///       3. first producto_precios for this product (lowest orden)
  ///       4. productos.precio
  ///       5. 0
  /// COALESCE short-circuits so chain steps 2-4 only execute on legacy zero-precio rows.
  Future<void> recalcCuentaCorrienteAllForUser(
    String userId, {
    bool markDirty = false,
  }) async {
    final today = argTodayFecha();

    await customStatement(
      '''
      UPDATE clientes
      SET cuenta_corriente =
        COALESCE((
          SELECT SUM(p.monto)
          FROM pagos p
          WHERE p.cliente_id = clientes.id
            AND p.metodo_pago NOT IN ('no_pago','no_compro','ausente','saltado')
            AND p.fecha != ''
            AND p.fecha <= ?
        ), 0.0) -
        COALESCE((
          SELECT SUM(e.entregado * COALESCE(
            NULLIF(e.precio_unitario, 0),
            (SELECT pp.precio FROM producto_precios pp
               INNER JOIN cliente_productos cp ON cp.precio_tipo_id = pp.id
              WHERE cp.cliente_id = e.cliente_id
                AND cp.producto_id = e.producto_id
              LIMIT 1),
            (SELECT pp2.precio FROM producto_precios pp2
              WHERE pp2.producto_id = e.producto_id
              ORDER BY pp2.orden ASC LIMIT 1),
            (SELECT pr.precio FROM productos pr WHERE pr.id = e.producto_id),
            0
          ))
          FROM entregas e
          WHERE e.cliente_id = clientes.id
            AND e.entregado > 0
            AND e.fecha != ''
            AND e.fecha <= ?
        ), 0.0)
      WHERE reparto_id IN (SELECT id FROM repartos WHERE user_id = ?)
    ''',
      [today, today, userId],
    );
    // F4: bulk recalc defaults to markDirty=false because the canonical
    // caller is _restoreFromCloud — at that point we're converging on
    // cloud truth, not generating new edits to push back. User-initiated
    // bulk recalcs (none exist today) can opt in.
    if (markDirty) {
      await customStatement(
        '''
        UPDATE clientes
        SET dirty = 1, updated_at = ?, dirty_fields = 'cuenta_corriente'
        WHERE reparto_id IN (SELECT id FROM repartos WHERE user_id = ?)
        ''',
        [LogicalClock.nextMs(), userId],
      );
    }
  }

  Future<void> recomputeClientesWithExpiringRows() async {
    final today = argTodayFecha();
    final lastRow = await customSelect(
      'SELECT last_cc_expiry_recompute_date FROM user_settings WHERE id = 1',
    ).get();
    final lastDate = lastRow.isEmpty
        ? ''
        : (lastRow.first.readNullable<String>(
                'last_cc_expiry_recompute_date',
              ) ??
              '');
    if (lastDate == today) return;

    final clienteIdsQuery = await customSelect(
      'SELECT DISTINCT cliente_id FROM ('
      "  SELECT cliente_id FROM entregas "
      "  WHERE fecha != '' AND fecha > ? AND fecha <= ? "
      '  UNION '
      "  SELECT cliente_id FROM pagos "
      "  WHERE fecha != '' AND fecha > ? AND fecha <= ?"
      ')',
      variables: [
        Variable.withString(lastDate),
        Variable.withString(today),
        Variable.withString(lastDate),
        Variable.withString(today),
      ],
    ).get();

    for (final r in clienteIdsQuery) {
      await recalcCuentaCorrienteForCliente(
        r.read<int>('cliente_id'),
        markDirty: true,
      );
    }

    await customStatement(
      'UPDATE user_settings SET last_cc_expiry_recompute_date = ? WHERE id = 1',
      [today],
    );
  }

  // --- Repartos ---

  Future<int> createReparto(String nombre, String userId) async {
    final id = await into(
      repartos,
    ).insert(RepartosCompanion.insert(nombre: nombre, userId: userId));
    await stampRowDirty('repartos', id);
    onDataChanged?.call();
    return id;
  }

  Future<List<Reparto>> getRepartosForUser(String userId) {
    return (select(repartos)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.orden),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// Hard-delete a reparto and every row that belongs to it.
  /// When [userId] is supplied a `repartos` tombstone is recorded inside
  /// the same transaction so SyncService can replay the cloud cascade
  /// (the bespoke child-row delete chain that lives in
  /// `SyncService.deleteRepartoFromCloud`) even if the device was offline
  /// or the immediate cloud DELETE failed. Sign-out wipe paths omit
  /// userId by convention to avoid scheduling deletions on next login.
  Future<void> deleteReparto(int repartoId, {String? userId}) async {
    await transaction(() async {
      if (userId != null) {
        await markPendingDeletion('repartos', repartoId, userId);
      }
      // Delete in dependency order: children first, then parents
      await (delete(
        entregas,
      )..where((t) => t.repartoId.equals(repartoId))).go();
      await (delete(pagos)..where((t) => t.repartoId.equals(repartoId))).go();
      await (delete(
        resumenes,
      )..where((t) => t.repartoId.equals(repartoId))).go();
      await (delete(
        cargaDiaria,
      )..where((t) => t.repartoId.equals(repartoId))).go();
      await (delete(
        facturas,
      )..where((t) => t.repartoId.equals(repartoId))).go();
      await (delete(
        etiquetaColors,
      )..where((t) => t.repartoId.equals(repartoId))).go();
      await (delete(
        stockNotifSettings,
      )..where((t) => t.repartoId.equals(repartoId))).go();
      // Delete cliente_productos for clients of this reparto
      await customStatement(
        'DELETE FROM cliente_productos WHERE cliente_id IN (SELECT id FROM clientes WHERE reparto_id = ?)',
        [repartoId],
      );
      await (delete(
        clientes,
      )..where((t) => t.repartoId.equals(repartoId))).go();
      await (delete(
        productoPrecios,
      )..where((t) => t.repartoId.equals(repartoId))).go();
      await (delete(
        productos,
      )..where((t) => t.repartoId.equals(repartoId))).go();
      await (delete(repartos)..where((t) => t.id.equals(repartoId))).go();
    });
    onDataChanged?.call();
  }

  // --- Productos ---

  Future<List<Producto>> getAllProducts(int repartoId) {
    return (select(productos)
          ..where(
            (t) => t.repartoId.equals(repartoId) & t.deleted.equals(false),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.orden),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// Returns all products including soft-deleted ones (for rankings/history).
  Future<List<Producto>> getAllProductsIncludingDeleted(int repartoId) {
    return (select(productos)
          ..where((t) => t.repartoId.equals(repartoId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.orden),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// Returns ALL products across all repartos (for sync push only).
  Future<List<Producto>> getAllProductsAllRepartos() {
    return (select(
      productos,
    )..orderBy([(t) => OrderingTerm.asc(t.orden)])).get();
  }

  Future<int> createProduct(
    int repartoId,
    String nombre, {
    double precio = 0.0,
  }) async {
    // Append after the current last position (MAX+1). COUNT misplaces a new
    // product whenever the existing `orden` values are non-contiguous.
    final existing = await (select(
      productos,
    )..where((t) => t.repartoId.equals(repartoId))).get();
    var maxOrden = -1;
    for (final p in existing) {
      if (p.orden > maxOrden) maxOrden = p.orden;
    }
    final id = await into(productos).insert(
      ProductosCompanion.insert(
        nombre: nombre,
        repartoId: Value(repartoId),
        orden: Value(maxOrden + 1),
        precio: Value(precio),
      ),
    );
    await stampRowDirty('productos', id);
    onDataChanged?.call();
    return id;
  }

  Future<void> updateProductPrecio(int productId, double precio) async {
    await (update(productos)..where((t) => t.id.equals(productId))).write(
      ProductosCompanion(precio: Value(precio)),
    );
    await markProductoPrecioDirty(productId);
    await stampRowDirty('productos', productId);
    onDataChanged?.call();
  }

  Future<void> updateProductPrecioMayorista(
    int productId,
    double? mayorista,
  ) async {
    final value = mayorista != null && mayorista < 0 ? null : mayorista;
    await customStatement(
      'UPDATE productos SET precio_mayorista = ?, '
      'precio_mayorista_dirty = 1, updated_at = ?, dirty = 1 '
      'WHERE id = ?',
      [value, LogicalClock.nextMs(), productId],
    );
    onDataChanged?.call();
  }

  Future<void> markProductoPrecioDirty(int productoId) async {
    await customStatement(
      'UPDATE productos SET precio_dirty = 1 WHERE id = ?',
      [productoId],
    );
  }

  Future<void> clearProductoPrecioDirty(List<int> ids) async {
    if (ids.isEmpty) return;
    for (var i = 0; i < ids.length; i += 500) {
      final end = (i + 500).clamp(0, ids.length);
      final batch = ids.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');
      await customStatement(
        'UPDATE productos SET precio_dirty = 0 WHERE id IN ($placeholders)',
        batch,
      );
    }
  }

  Future<void> clearProductoPrecioMayoristaDirty(List<int> ids) async {
    if (ids.isEmpty) return;
    for (var i = 0; i < ids.length; i += 500) {
      final end = (i + 500).clamp(0, ids.length);
      final batch = ids.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');
      await customStatement(
        'UPDATE productos SET precio_mayorista_dirty = 0 '
        'WHERE id IN ($placeholders)',
        batch,
      );
    }
  }

  Future<void> clearProductoPackSizeDirty(List<int> ids) async {
    if (ids.isEmpty) return;
    for (var i = 0; i < ids.length; i += 500) {
      final end = (i + 500).clamp(0, ids.length);
      final batch = ids.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');
      await customStatement(
        'UPDATE productos SET pack_size_dirty = 0 WHERE id IN ($placeholders)',
        batch,
      );
    }
  }

  /// P0-1: atomic guarded clear for productos — row dirty AND the three
  /// per-column dirty flags drop together, but ONLY when updated_at still
  /// matches the push snapshot. A producto edited mid-push (nombre, precio,
  /// pack…) keeps every flag it had plus the new edit's stamps, so the next
  /// cycle re-pushes the fresh state. (Single statement per row so the row
  /// flag can never clear without its column flags or vice versa.)
  Future<void> clearProductosDirtyAndColumnDirty(
    List<Map<String, Object?>> snapshotRows,
  ) async {
    if (snapshotRows.isEmpty) return;
    await transaction(() async {
      for (final row in snapshotRows) {
        await customStatement(
          'UPDATE productos SET dirty = 0, precio_dirty = 0, '
          'precio_mayorista_dirty = 0, pack_size_dirty = 0 '
          'WHERE id = ? AND updated_at = ?',
          [row['id'], row['updated_at']],
        );
      }
    });
  }

  /// v63: read the pack_size for one product. Null when no pack is set.
  Future<int?> getProductoPackSize(int productId) async {
    final rows = await customSelect(
      'SELECT pack_size FROM productos WHERE id = ?',
      variables: [Variable.withInt(productId)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.read<int?>('pack_size');
  }

  Future<double?> getProductoMayorista(int productId) async {
    final rows = await customSelect(
      'SELECT precio_mayorista FROM productos WHERE id = ?',
      variables: [Variable.withInt(productId)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.read<double?>('precio_mayorista');
  }

  Future<void> setProductoPackSize(int productId, int? packSize) async {
    // Pack is OFF when packSize is null or < 2. A pack-of-1 makes no
    // semantic sense (every item would be its own pack), so anything
    // below the minimum stores as NULL = "not a pack".
    final value = (packSize != null && packSize >= 2) ? packSize : null;
    await customStatement(
      // pack_size_dirty = 1 guards this edit during a concurrent cloud pull
      // (mirrors precio_dirty); cleared after a successful push.
      'UPDATE productos SET pack_size = ?, pack_size_dirty = 1, '
      'updated_at = ?, dirty = 1 WHERE id = ?',
      [value, LogicalClock.nextMs(), productId],
    );
    onDataChanged?.call();
  }

  /// Bulk read pack sizes for a reparto, keyed by product id. Useful for
  /// aggregations so screens do not issue N+1 queries.
  Future<Map<int, int>> getProductoPackSizesForReparto(int repartoId) async {
    final rows = await customSelect(
      'SELECT id, pack_size FROM productos WHERE reparto_id = ? '
      'AND pack_size IS NOT NULL AND pack_size >= 2',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return {for (final r in rows) r.read<int>('id'): r.read<int>('pack_size')};
  }

  Future<Map<int, double>> getProductosMayoristaForReparto(
    int repartoId,
  ) async {
    final rows = await customSelect(
      'SELECT id, precio_mayorista FROM productos WHERE reparto_id = ? '
      'AND precio_mayorista IS NOT NULL',
      variables: [Variable.withInt(repartoId)],
    ).get();
    final result = <int, double>{};
    for (final r in rows) {
      final mayorista = r.read<double?>('precio_mayorista');
      if (mayorista == null) continue;
      result[r.read<int>('id')] = mayorista;
    }
    return result;
  }

  // --- Producto Precios ---

  Future<List<ProductoPrecio>> getProductoPrecios(int productoId) {
    return (select(productoPrecios)
          ..where((t) => t.productoId.equals(productoId))
          ..orderBy([(t) => OrderingTerm.asc(t.orden)]))
        .get();
  }

  Future<List<ProductoPrecio>> getAllProductoPrecios(int repartoId) {
    return (select(productoPrecios)
          ..where((t) => t.repartoId.equals(repartoId))
          ..orderBy([(t) => OrderingTerm.asc(t.orden)]))
        .get();
  }

  /// Returns ALL producto_precios across all repartos (for sync push only).
  Future<List<ProductoPrecio>> getAllProductoPreciosAllRepartos() {
    return (select(
      productoPrecios,
    )..orderBy([(t) => OrderingTerm.asc(t.orden)])).get();
  }

  Future<int> createProductoPrecio(
    int repartoId,
    int productoId,
    String nombre,
    double precio,
  ) async {
    // Append after the current last position (MAX+1) so a non-contiguous
    // `orden` set can't misplace the new tier.
    final existing = await (select(
      productoPrecios,
    )..where((t) => t.productoId.equals(productoId))).get();
    var maxOrden = -1;
    for (final p in existing) {
      if (p.orden > maxOrden) maxOrden = p.orden;
    }
    final id = await into(productoPrecios).insert(
      ProductoPreciosCompanion.insert(
        productoId: productoId,
        repartoId: Value(repartoId),
        nombre: nombre,
        precio: precio,
        orden: Value(maxOrden + 1),
      ),
    );
    await stampRowDirty('producto_precios', id);
    onDataChanged?.call();
    return id;
  }

  Future<void> updateProductoPrecioValue(int precioId, double precio) async {
    await (update(productoPrecios)..where((t) => t.id.equals(precioId))).write(
      ProductoPreciosCompanion(precio: Value(precio)),
    );
    await stampRowDirty('producto_precios', precioId);
    onDataChanged?.call();
  }

  Future<void> updateProductoPrecioName(int precioId, String nombre) async {
    await (update(productoPrecios)..where((t) => t.id.equals(precioId))).write(
      ProductoPreciosCompanion(nombre: Value(nombre)),
    );
    await stampRowDirty('producto_precios', precioId);
    onDataChanged?.call();
  }

  /// Archive a product and remove catalog-side configuration.
  /// Phase 11a: optional [userId] now creates a `pending_deletions`
  /// tombstone in the SAME transaction as the local cascade. Without
  /// it, an offline-then-online phone would silently drop the cloud
  /// deletion: the user-initiated deleteProduct from carga_screen ran
  /// the immediate cloud cascade via `deleteProductFromCloud`, but if
  /// that failed (offline or transient error), nothing remembered to
  /// retry on next sync. Sibling devices never learned about the
  /// delete — the row was resurrected on their next push.
  Future<void> deleteProduct(int productId, {String? userId}) async {
    await transaction(() async {
      if (userId != null) {
        await markPendingDeletion('productos', productId, userId);
      }
      await (delete(
        productoPrecios,
      )..where((t) => t.productoId.equals(productId))).go();
      await (delete(
        clienteProductos,
      )..where((t) => t.productoId.equals(productId))).go();
      await (delete(
        cargaDiaria,
      )..where((t) => t.productoId.equals(productId))).go();
      await (delete(
        stockNotifSettings,
      )..where((t) => t.productoId.equals(productId))).go();
      await customStatement(
        'DELETE FROM habitual_product_settings WHERE producto_id = ?',
        [productId],
      );
      await (update(productos)..where((t) => t.id.equals(productId))).write(
        ProductosCompanion(deleted: const Value(true)),
      );
      await stampRowDirty('productos', productId);
    });
    onDataChanged?.call();
  }

  Future<void> deleteProductoPrecio(int precioId, String userId) async {
    // Atomic: tombstone + local delete must either both land or neither, so the
    // cloud deletion can't be resurrected if the app is killed mid-operation.
    await transaction(() async {
      // F4: stamp dirty BEFORE the NULL update so the WHERE precio_tipo_id =
      // ? clause still matches. After the NULL update, precio_tipo_id is
      // NULL and we'd have nothing to filter on.
      await _stampClienteProductosDirtyByPrecioTipo(precioId);
      await customStatement(
        'UPDATE cliente_productos SET precio_tipo_id = NULL WHERE precio_tipo_id = ?',
        [precioId],
      );
      await markPendingDeletion('producto_precios', precioId, userId);
      await (delete(productoPrecios)..where((t) => t.id.equals(precioId))).go();
    });
    onDataChanged?.call();
  }

  Future<void> setClientePrecioTipo(
    int clienteId,
    int productoId,
    int? precioTipoId,
  ) async {
    final cpResults =
        await (select(clienteProductos)
              ..where(
                (t) =>
                    t.clienteId.equals(clienteId) &
                    t.productoId.equals(productoId),
              )
              ..limit(1))
            .get();
    final existing = cpResults.isEmpty ? null : cpResults.first;
    final int rowId;
    if (existing != null) {
      await (update(
        clienteProductos,
      )..where((t) => t.id.equals(existing.id))).write(
        ClienteProductosCompanion(
          precioTipoId: precioTipoId != null
              ? Value(precioTipoId)
              : const Value(null),
        ),
      );
      rowId = existing.id;
    } else {
      rowId = await into(clienteProductos).insert(
        ClienteProductosCompanion.insert(
          clienteId: clienteId,
          productoId: productoId,
          precioTipoId: Value(precioTipoId),
        ),
      );
    }
    // F4: precio_tipo_id change needs to sync.
    await _stampClienteProductoDirty(rowId);
    onDataChanged?.call();
  }

  /// Get effective price for a product for a specific client.
  /// Uses client's selected price type if set, otherwise first price type, otherwise product.precio.
  Future<double> getEffectivePrice(int clienteId, int productoId) async {
    final cpResults =
        await (select(clienteProductos)
              ..where(
                (t) =>
                    t.clienteId.equals(clienteId) &
                    t.productoId.equals(productoId),
              )
              ..limit(1))
            .get();
    final cp = cpResults.isEmpty ? null : cpResults.first;
    if (cp?.precioTipoId != null) {
      final pp = await (select(
        productoPrecios,
      )..where((t) => t.id.equals(cp!.precioTipoId!))).getSingleOrNull();
      if (pp != null) return pp.precio;
    }
    // Fallback to first price type for the product
    final prices = await getProductoPrecios(productoId);
    if (prices.isNotEmpty) return prices.first.precio;
    // Final fallback to product.precio
    final product = await (select(
      productos,
    )..where((t) => t.id.equals(productoId))).getSingleOrNull();
    return product?.precio ?? 0.0;
  }

  // --- Carga (scoped by reparto) ---

  Future<Map<int, int>> getCargaForDay(
    int repartoId,
    int diaSemana,
    String semana,
  ) async {
    final entries =
        await (select(cargaDiaria)..where(
              (t) =>
                  t.repartoId.equals(repartoId) &
                  t.diaSemana.equals(diaSemana) &
                  t.semana.equals(semana),
            ))
            .get();
    return {for (final e in entries) e.productoId: e.cantidad};
  }

  /// Returns `Map<productId, {cantidad, remanente}>` for a given day
  // Guards a one-shot, per-process defensive schema check for the
  // `remanente` column on carga_diaria. Devices that came from very old
  // builds — or that pulled a cloud row whose schema didn't include
  // remanente — could otherwise read NULL or hit "no such column" inside
  // the query below and break Carga loading.
  bool _cargaSchemaChecked = false;

  Future<Map<int, ({int cantidad, int remanente})>> getCargaForDayWithRemanente(
    int repartoId,
    int diaSemana,
    String semana,
  ) async {
    if (!_cargaSchemaChecked) {
      try {
        await _ensureColumn(
          'carga_diaria',
          'remanente',
          'INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // Idempotent re-ensure; if it fails we still try the read and
        // the readNullable fallback below will absorb the surprise.
      }
      _cargaSchemaChecked = true;
    }
    final rows = await customSelect(
      'SELECT producto_id, cantidad, remanente FROM carga_diaria WHERE reparto_id = ? AND dia_semana = ? AND semana = ?',
      variables: [Variable(repartoId), Variable(diaSemana), Variable(semana)],
    ).get();
    return {
      for (final r in rows)
        r.read<int>('producto_id'): (
          // readNullable + ?? 0 so a stray NULL from an older cloud
          // payload doesn't throw and yank the whole Carga screen
          // into the error snackbar.
          cantidad: r.readNullable<int>('cantidad') ?? 0,
          remanente: r.readNullable<int>('remanente') ?? 0,
        ),
    };
  }

  // --- Clientes ---

  Future<int> createCliente(
    int repartoId,
    int diaSemana,
    String nombre, {
    String direccion = '',
    String telefono = '',
    String frecuencia = 'semanal',
    String etiqueta = '',
    String notas = '',
    double? lat,
    double? lng,
  }) async {
    // Append after the current last position. Using COUNT() was wrong: once a
    // day's `orden` values are non-contiguous (after a delete, or when the web
    // admin reordered to 10/20/30…), COUNT lands the new client at the wrong
    // relative position (e.g. 3 sorts before 10/20/30, jumping it to the top),
    // and that bad orden then syncs out as a spontaneous reshuffle. MAX+1
    // always appends, matching moveClienteDayPermanent and the web.
    final orderRows = await customSelect(
      'SELECT COALESCE(MAX(orden), -1) + 1 AS next_orden '
      'FROM clientes WHERE reparto_id = ? AND dia_semana = ?',
      variables: [Variable.withInt(repartoId), Variable.withInt(diaSemana)],
    ).get();
    final nextOrden = orderRows.first.read<int>('next_orden');
    final id = await into(clientes).insert(
      ClientesCompanion.insert(
        repartoId: repartoId,
        diaSemana: diaSemana,
        nombre: nombre,
        direccion: Value(direccion),
        telefono: Value(telefono),
        frecuencia: Value(frecuencia),
        etiqueta: Value(etiqueta),
        notas: Value(notas),
        orden: Value(nextOrden),
      ),
    );
    // Phase G — Places autocomplete pick: write the captured coords + stamp
    // geocoded_direccion so ruta_screen._geocodeClients sees the row as
    // already resolved and doesn't re-hit the device-side geocoder. Columns
    // live on the raw-SQL side of the schema (not on the Drift Table), so
    // we go through customStatement.
    if (lat != null && lng != null) {
      await customStatement(
        'UPDATE clientes SET lat = ?, lng = ?, geocoded_direccion = ? '
        'WHERE id = ?',
        [lat, lng, direccion, id],
      );
    }
    // v52: mark the new row dirty so the next sync push includes it.
    // `updated_at` is the wall-clock moment of creation; the cloud
    // reject-stale-update trigger uses it to order writes.
    await _stampClienteDirty(id, fields: const {'all'});
    onDataChanged?.call();
    return id;
  }

  static Set<String> _decodeDirtyFields(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String>{};
    return raw
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toSet();
  }

  static String _encodeDirtyFields(Set<String> fields) {
    if (fields.contains('all')) return 'all';
    final sorted = fields.where((f) => f.isNotEmpty).toList()..sort();
    return sorted.join(',');
  }

  /// Stamps `dirty = 1` + `updated_at = nowMs` on a clientes row and records
  /// the exact cloud columns that changed locally. This is intentionally more
  /// granular than the original v52 row-level dirty bit: a local reorder must
  /// not upload stale profile fields such as direccion.
  Future<void> _stampClienteDirty(
    int clienteId, {
    required Iterable<String> fields,
  }) async {
    final nextFields = fields.toSet();
    if (nextFields.isEmpty) return;
    final existingRows = await customSelect(
      'SELECT dirty, dirty_fields FROM clientes WHERE id = ? LIMIT 1',
      variables: [Variable.withInt(clienteId)],
    ).get();
    if (existingRows.isEmpty) return;
    final existingDirty = existingRows.first.read<int>('dirty') == 1;
    final merged = existingDirty
        ? _decodeDirtyFields(existingRows.first.read<String>('dirty_fields'))
        : <String>{};
    merged.addAll(nextFields);
    await customStatement(
      'UPDATE clientes SET dirty = 1, updated_at = ?, dirty_fields = ? '
      'WHERE id = ?',
      [LogicalClock.nextMs(), _encodeDirtyFields(merged), clienteId],
    );
  }

  /// F4: stamp dirty on a single cliente_productos row by id. Mirrors
  /// `_stampClienteDirty` for the cliente_productos table.
  Future<void> _stampClienteProductoDirty(int rowId) async {
    await customStatement(
      'UPDATE cliente_productos SET dirty = 1, updated_at = ? WHERE id = ?',
      [LogicalClock.nextMs(), rowId],
    );
  }

  /// F4: stamp dirty on every cliente_productos row matching a `precio_tipo_id`.
  /// Used by `deleteProductoPrecio` when nulling out references to the
  /// price type being deleted — those affected rows now have a changed
  /// value that needs to reach cloud.
  Future<void> _stampClienteProductosDirtyByPrecioTipo(int precioTipoId) async {
    await customStatement(
      'UPDATE cliente_productos SET dirty = 1, updated_at = ? WHERE precio_tipo_id = ?',
      [LogicalClock.nextMs(), precioTipoId],
    );
  }

  Future<Cliente?> getCliente(int id) async {
    final results =
        await (select(clientes)
              ..where((t) => t.id.equals(id))
              ..limit(1))
            .get();
    return results.isEmpty ? null : results.first;
  }

  Future<List<Cliente>> getClientesForReparto(int repartoId) {
    return (select(clientes)
          ..where((t) => t.repartoId.equals(repartoId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.diaSemana),
            (t) => OrderingTerm.asc(t.orden),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// Today's local date in yyyy-MM-dd, used as the "key" for one-day
  /// cliente day overrides (v49). When the override's date matches this,
  /// the cliente is reslotted into `temp_dia_semana` for today only.
  String _todayDateStr() {
    final d = argentinaTime();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  /// Returns clientes for the given route + day-of-week, respecting today's
  /// one-day overrides. A cliente with a live override (temp_dia_date ==
  /// today) appears on its temp_dia_semana, not its permanent dia_semana.
  /// Expired overrides are ignored — past temp_dia_date values fall through
  /// to the permanent day naturally, so no cleanup timer is required.
  Future<List<Cliente>> getClientesForRepartoDay(
    int repartoId,
    int diaSemana,
  ) async {
    final all = await (select(
      clientes,
    )..where((t) => t.repartoId.equals(repartoId))).get();
    if (all.isEmpty) return all;
    // Read override columns via raw SQL (not in the Drift Table class).
    final today = _todayDateStr();
    final overrideRows = await customSelect(
      'SELECT id, temp_dia_semana, temp_dia_date FROM clientes WHERE reparto_id = ?',
      variables: [Variable.withInt(repartoId)],
    ).get();
    // clienteId -> active-override day (only if temp_dia_date == today).
    final activeOverride = <int, int>{};
    for (final r in overrideRows) {
      final date = r.readNullable<String>('temp_dia_date');
      final tdow = r.readNullable<int>('temp_dia_semana');
      if (date == today && tdow != null) {
        activeOverride[r.read<int>('id')] = tdow;
      }
    }
    final result = all.where((c) {
      final ov = activeOverride[c.id];
      // With an active override, effective day = override. Without one, the
      // cliente's permanent dia_semana drives the filter.
      final effectiveDay = ov ?? c.diaSemana;
      return effectiveDay == diaSemana;
    }).toList();
    result.sort((a, b) {
      final aBorrowed =
          activeOverride.containsKey(a.id) && a.diaSemana != diaSemana;
      final bBorrowed =
          activeOverride.containsKey(b.id) && b.diaSemana != diaSemana;
      if (aBorrowed != bBorrowed) return aBorrowed ? 1 : -1;
      final orderCmp = a.orden.compareTo(b.orden);
      return orderCmp != 0 ? orderCmp : a.id.compareTo(b.id);
    });
    return result;
  }

  /// Set a one-day override: cliente is reslotted to [day] for today only.
  /// Today is computed inside so callers don't have to thread the date in.
  Future<void> setClienteTempDay(int clienteId, int day) async {
    final today = _todayDateStr();
    await customStatement(
      'UPDATE clientes SET temp_dia_semana = ?, temp_dia_date = ? WHERE id = ?',
      [day, today, clienteId],
    );
    onLocalDataChanged?.call();
  }

  /// Clear any one-day override on a cliente without scheduling cloud sync.
  Future<void> clearClienteTempDay(int clienteId) async {
    await customStatement(
      'UPDATE clientes SET temp_dia_semana = NULL, temp_dia_date = NULL WHERE id = ?',
      [clienteId],
    );
    onLocalDataChanged?.call();
  }

  Future<Set<int>> getMarkedClientesForWeek(String semana) async {
    final rows = await customSelect(
      'SELECT id FROM clientes WHERE marked_semana = ?',
      variables: [Variable.withString(semana)],
    ).get();
    return rows.map((r) => r.read<int>('id')).toSet();
  }

  Future<void> setClienteMarked(int clienteId, String semana) async {
    await customStatement(
      'UPDATE clientes SET marked_semana = ? WHERE id = ?',
      [semana, clienteId],
    );
    await _stampClienteDirty(clienteId, fields: const {'marked_semana'});
  }

  Future<void> clearClienteMark(int clienteId) async {
    await customStatement(
      'UPDATE clientes SET marked_semana = NULL WHERE id = ?',
      [clienteId],
    );
    await _stampClienteDirty(clienteId, fields: const {'marked_semana'});
  }

  /// Read every cliente's cached geocode for this reparto. Lets Ruta
  /// hydrate the map markers from DB at first frame instead of re-geocoding
  /// every direccion on every open. Returns rows where lat AND lng are
  /// non-null. `geocoded_direccion` is the address used for the geocode —
  /// callers should compare it to the current direccion before trusting
  /// the cached lat/lng (an edited address invalidates the cache).
  Future<List<Map<String, dynamic>>> getClienteGeocodesForReparto(
    int repartoId,
  ) async {
    final rows = await customSelect(
      'SELECT id, lat, lng, geocoded_direccion FROM clientes '
      'WHERE reparto_id = ? AND lat IS NOT NULL AND lng IS NOT NULL',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return rows
        .map(
          (r) => {
            'id': r.read<int>('id'),
            'lat': r.read<double>('lat'),
            'lng': r.read<double>('lng'),
            'geocoded_direccion':
                r.readNullable<String>('geocoded_direccion') ?? '',
          },
        )
        .toList();
  }

  /// Persist a freshly-geocoded result for a cliente so the next open of
  /// Ruta can read it back without hitting the device geocoder. Local-only
  /// for now — the same columns exist in the cloud `clientes` table but
  /// they are NOT in sync_service's cliente push, so this write doesn't
  /// travel to other devices. Web admin populates the cloud columns on
  /// its own schedule via Google Geocoding API.
  Future<void> setClienteGeocode(
    int clienteId,
    double lat,
    double lng,
    String address,
  ) async {
    await customStatement(
      'UPDATE clientes SET lat = ?, lng = ?, geocoded_direccion = ? WHERE id = ?',
      [lat, lng, address, clienteId],
    );
    // Intentionally NOT calling onDataChanged — geocode is a per-device
    // cache, has no business impact, and firing onDataChanged would
    // bounce through the home_screen listener for nothing.
  }

  Future<int?> getClienteActiveTempDay(int clienteId) async {
    final rows = await customSelect(
      'SELECT temp_dia_semana, temp_dia_date FROM clientes WHERE id = ?',
      variables: [Variable.withInt(clienteId)],
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    final date = row.readNullable<String>('temp_dia_date');
    final day = row.readNullable<int>('temp_dia_semana');
    return date == _todayDateStr() ? day : null;
  }

  Future<void> moveClienteDayPermanent(int clienteId, int day) async {
    await transaction(() async {
      final rows = await customSelect(
        'SELECT reparto_id, dia_semana, orden FROM clientes WHERE id = ? LIMIT 1',
        variables: [Variable.withInt(clienteId)],
      ).get();
      if (rows.isEmpty) return;
      final current = rows.first;
      final repartoId = current.read<int>('reparto_id');
      final oldDay = current.read<int>('dia_semana');
      final oldOrden = current.read<int>('orden');
      final orderRows = await customSelect(
        'SELECT COALESCE(MAX(orden), -1) + 1 AS next_orden '
        'FROM clientes WHERE reparto_id = ? AND dia_semana = ? AND id != ?',
        variables: [
          Variable.withInt(repartoId),
          Variable.withInt(day),
          Variable.withInt(clienteId),
        ],
      ).get();
      final nextOrden = oldDay == day
          ? oldOrden
          : orderRows.first.read<int>('next_orden');
      await (update(clientes)..where((t) => t.id.equals(clienteId))).write(
        ClientesCompanion(diaSemana: Value(day), orden: Value(nextOrden)),
      );
      await customStatement(
        'UPDATE clientes SET temp_dia_semana = NULL, temp_dia_date = NULL WHERE id = ?',
        [clienteId],
      );
      // F4: dia_semana change needs to sync — without this stamp the
      // permanent day move only lives locally.
      await _stampClienteDirty(
        clienteId,
        fields: const {'dia_semana', 'orden'},
      );
    });
    onDataChanged?.call();
  }

  Future<void> updateCliente(
    int clienteId, {
    String? nombre,
    String? direccion,
    String? telefono,
    String? frecuencia,
    String? etiqueta,
    String? notas,
    int? diaSemana,
    bool? showOnMap,
    int? docTipo,
    String? docNro,
    String? docNroCache,
    double? lat,
    double? lng,
  }) async {
    final rows = await customSelect(
      'SELECT nombre, direccion, telefono, frecuencia, etiqueta, notas, '
      'dia_semana, show_on_map, doc_tipo, doc_nro, doc_nro_cache, '
      'lat, lng, geocoded_direccion '
      'FROM clientes WHERE id = ? LIMIT 1',
      variables: [Variable.withInt(clienteId)],
    ).get();
    if (rows.isEmpty) return;
    final current = rows.first.data;
    final dirtyFields = <String>{};

    bool textChanged(String column, String? next) =>
        next != null && next != (current[column] as String? ?? '');
    bool intChanged(String column, int? next) =>
        next != null && next != (current[column] as int? ?? 0);
    bool boolChanged(String column, bool? next) {
      if (next == null) return false;
      final currentValue = current[column];
      final currentBool = currentValue == true || currentValue == 1;
      return next != currentBool;
    }

    final companion = ClientesCompanion(
      nombre: textChanged('nombre', nombre)
          ? Value(nombre!)
          : const Value.absent(),
      direccion: textChanged('direccion', direccion)
          ? Value(direccion!)
          : const Value.absent(),
      telefono: textChanged('telefono', telefono)
          ? Value(telefono!)
          : const Value.absent(),
      frecuencia: textChanged('frecuencia', frecuencia)
          ? Value(frecuencia!)
          : const Value.absent(),
      etiqueta: textChanged('etiqueta', etiqueta)
          ? Value(etiqueta!)
          : const Value.absent(),
      notas: textChanged('notas', notas) ? Value(notas!) : const Value.absent(),
      diaSemana: intChanged('dia_semana', diaSemana)
          ? Value(diaSemana!)
          : const Value.absent(),
      showOnMap: boolChanged('show_on_map', showOnMap)
          ? Value(showOnMap!)
          : const Value.absent(),
      docTipo: intChanged('doc_tipo', docTipo)
          ? Value(docTipo!)
          : const Value.absent(),
      docNro: textChanged('doc_nro', docNro)
          ? Value(docNro!)
          : const Value.absent(),
    );

    if (textChanged('nombre', nombre)) dirtyFields.add('nombre');
    if (textChanged('direccion', direccion)) dirtyFields.add('direccion');
    if (textChanged('telefono', telefono)) dirtyFields.add('telefono');
    if (textChanged('frecuencia', frecuencia)) dirtyFields.add('frecuencia');
    if (textChanged('etiqueta', etiqueta)) dirtyFields.add('etiqueta');
    if (textChanged('notas', notas)) dirtyFields.add('notas');
    if (intChanged('dia_semana', diaSemana)) dirtyFields.add('dia_semana');
    if (boolChanged('show_on_map', showOnMap)) dirtyFields.add('show_on_map');
    if (intChanged('doc_tipo', docTipo)) dirtyFields.add('doc_tipo');
    if (textChanged('doc_nro', docNro)) dirtyFields.add('doc_nro');

    if (dirtyFields.any(
      (f) => const {
        'nombre',
        'direccion',
        'telefono',
        'frecuencia',
        'etiqueta',
        'notas',
        'dia_semana',
        'show_on_map',
        'doc_tipo',
        'doc_nro',
      }.contains(f),
    )) {
      await (update(
        clientes,
      )..where((t) => t.id.equals(clienteId))).write(companion);
    }

    // Update raw SQL column for doc_nro_cache
    final currentCache = current['doc_nro_cache'] as String? ?? '{}';
    if (docNroCache != null && docNroCache != currentCache) {
      await customStatement(
        'UPDATE clientes SET doc_nro_cache = ? WHERE id = ?',
        [docNroCache, clienteId],
      );
    }
    // Phase G — Places autocomplete pick: stamp the captured coords and
    // mark geocoded_direccion = direccion so the device-side geocoder in
    // ruta_screen treats this row as already resolved. When direccion was
    // also passed we use it; otherwise we fall back to the row's current
    // direccion (defensive — shouldn't happen in the UI flow but keeps the
    // method honest if a caller passes coords without text).
    if (lat != null && lng != null) {
      final currentLat = (current['lat'] as num?)?.toDouble();
      final currentLng = (current['lng'] as num?)?.toDouble();
      final geoAddress = direccion ?? (current['direccion'] as String? ?? '');
      final currentGeo = current['geocoded_direccion'] as String?;
      if (currentLat != lat || currentLng != lng || currentGeo != geoAddress) {
        await customStatement(
          'UPDATE clientes SET lat = ?, lng = ?, geocoded_direccion = ? '
          'WHERE id = ?',
          [lat, lng, geoAddress, clienteId],
        );
        dirtyFields.addAll(const {'lat', 'lng', 'geocoded_direccion'});
      }
    }
    if (dirtyFields.isEmpty) return;
    await _stampClienteDirty(clienteId, fields: dirtyFields);
    onDataChanged?.call();
  }

  /// Read the doc_nro_cache JSON for a client (raw SQL column)
  Future<String> getClienteDocNroCache(int clienteId) async {
    final rows = await customSelect(
      'SELECT doc_nro_cache FROM clientes WHERE id = ?',
      variables: [Variable.withInt(clienteId)],
    ).get();
    if (rows.isNotEmpty) {
      return rows.first.data['doc_nro_cache'] as String? ?? '{}';
    }
    return '{}';
  }

  Future<void> updateCuentaCorriente(int clienteId, double monto) async {
    await (update(clientes)..where((t) => t.id.equals(clienteId))).write(
      ClientesCompanion(cuentaCorriente: Value(monto)),
    );
    // Cloud owns cuenta_corriente via the recompute trigger. When this helper
    // is used as an explicit manual adjustment, only that column is dirty; it
    // must never cause stale profile fields to be pushed.
    await _stampClienteDirty(clienteId, fields: const {'cuenta_corriente'});
    onDataChanged?.call();
  }

  /// Hard-delete a cliente plus its child rows (cliente_productos, entregas,
  /// pagos). When [userId] is supplied a `clientes` tombstone is recorded
  /// inside the same transaction so SyncService can replay the cloud
  /// deletion even if the device was offline or the immediate cloud DELETE
  /// failed. Callers that hard-clear local data without a user context
  /// (e.g. sign-out wipe) omit userId and intentionally skip the tombstone.
  Future<void> deleteCliente(int clienteId, {String? userId}) async {
    await transaction(() async {
      if (userId != null) {
        await markPendingDeletion('clientes', clienteId, userId);
      }
      await (delete(
        clienteProductos,
      )..where((t) => t.clienteId.equals(clienteId))).go();
      await (delete(
        entregas,
      )..where((t) => t.clienteId.equals(clienteId))).go();
      await (delete(pagos)..where((t) => t.clienteId.equals(clienteId))).go();
      await (delete(clientes)..where((t) => t.id.equals(clienteId))).go();
    });
    onDataChanged?.call();
  }

  /// Reorder clientes atomically. [ordenByClienteId] maps cliente id →
  /// target orden. ONE transaction: read the current orden of every id in
  /// a single SELECT, write only the rows whose PERSISTED orden differs,
  /// then fire onDataChanged ONCE after commit (only if something changed)
  /// so sync gets scheduled once instead of per row.
  ///
  /// This replaces the old per-row `updateClienteOrden` loop, whose
  /// row-by-row notify let screen reloads swap the caller's list mid-loop
  /// and persist a half-applied permutation ("clients randomly change
  /// order on load"). Diffing against the DB row — not the caller's
  /// in-memory Cliente, whose `.orden` goes stale after in-memory moves —
  /// makes the method immune to stale callers. Ids not found (deleted
  /// mid-flight) are skipped. Returns true when at least one row changed.
  Future<bool> updateClienteOrdenBatch(Map<int, int> ordenByClienteId) async {
    if (ordenByClienteId.isEmpty) return false;
    var changed = false;
    await transaction(() async {
      final rows = await (select(
        clientes,
      )..where((t) => t.id.isIn(ordenByClienteId.keys.toList()))).get();
      for (final row in rows) {
        final target = ordenByClienteId[row.id];
        if (target == null || row.orden == target) continue;
        await (update(clientes)..where((t) => t.id.equals(row.id))).write(
          ClientesCompanion(orden: Value(target)),
        );
        // Ordering is a synced field, but it is independent from cliente
        // profile data. Mark only orden so a reorder cannot upload a stale
        // direccion.
        await _stampClienteDirty(row.id, fields: const {'orden'});
        changed = true;
      }
    });
    // Notify AFTER commit — listeners must never read pre-commit state
    // (same rule as deleteCliente above).
    if (changed) onDataChanged?.call();
    return changed;
  }

  // --- ClienteProductos ---

  Future<void> setClienteProducto(
    int clienteId,
    int productoId,
    int cantidadHabitual,
  ) async {
    final results =
        await (select(clienteProductos)
              ..where(
                (t) =>
                    t.clienteId.equals(clienteId) &
                    t.productoId.equals(productoId),
              )
              ..limit(1))
            .get();
    final existing = results.isEmpty ? null : results.first;
    final int rowId;
    if (existing != null) {
      await (update(
        clienteProductos,
      )..where((t) => t.id.equals(existing.id))).write(
        ClienteProductosCompanion(cantidadHabitual: Value(cantidadHabitual)),
      );
      rowId = existing.id;
    } else {
      rowId = await into(clienteProductos).insert(
        ClienteProductosCompanion.insert(
          clienteId: clienteId,
          productoId: productoId,
          cantidadHabitual: Value(cantidadHabitual),
        ),
      );
    }
    // v52: stamp dirty so the new habitual reaches cloud.
    await customStatement(
      'UPDATE cliente_productos SET dirty = 1, updated_at = ? WHERE id = ?',
      [LogicalClock.nextMs(), rowId],
    );
    onDataChanged?.call();
  }

  Future<List<ClienteProducto>> getClienteProductos(int clienteId) {
    return (select(
      clienteProductos,
    )..where((t) => t.clienteId.equals(clienteId))).get();
  }

  Future<Map<int, List<ClienteProducto>>> getClienteProductosForRepartoDay(
    int repartoId,
    int diaSemana,
  ) async {
    final rows =
        await (select(clienteProductos).join([
              innerJoin(
                clientes,
                clientes.id.equalsExp(clienteProductos.clienteId),
              ),
            ])..where(
              clientes.repartoId.equals(repartoId) &
                  clientes.diaSemana.equals(diaSemana),
            ))
            .get();

    final result = <int, List<ClienteProducto>>{};
    for (final row in rows) {
      final cp = row.readTable(clienteProductos);
      result.putIfAbsent(cp.clienteId, () => []).add(cp);
    }
    return result;
  }

  // --- Entregas ---

  Future<Entrega?> getEntrega(
    int clienteId,
    int repartoId,
    int productoId,
    String semana,
    int diaSemana,
  ) async {
    final results =
        await (select(entregas)
              ..where(
                (t) =>
                    t.clienteId.equals(clienteId) &
                    t.repartoId.equals(repartoId) &
                    t.productoId.equals(productoId) &
                    t.semana.equals(semana) &
                    t.diaSemana.equals(diaSemana),
              )
              ..limit(1))
            .get();
    return results.isEmpty ? null : results.first;
  }

  Future<void> setEntrega(
    int clienteId,
    int repartoId,
    int productoId,
    String semana,
    int diaSemana,
    int entregado,
    int devuelto, {
    double precioUnitario = 0.0,
    bool preserveExistingSnapshot = false,
    // ignore: avoid_init_to_null
    String? fecha = null,
  }) async {
    // Atomic UPSERT + cuenta_corriente recalc inside a single transaction.
    // Replaces the v30 SELECT-then-INSERT/UPDATE pattern that raced under
    // sync.
    //
    // Snapshot rule: by default the incoming `precio_unitario` ALWAYS wins.
    // The optional `preserveExistingSnapshot` flag restores the old CASE rule
    // only for historical edits that must keep an existing nonzero snapshot.
    // Keeping it opt-in preserves one-shot "Precio para hoy" semantics: the
    // in-memory _overridePrices map gets cleared on app restart / day switch /
    // midnight, while the entrega row's snapshot lives forever, so normal +/-
    // taps must keep stamping the fresh caller-provided price instead of
    // preserving an orphaned override.
    //
    // Callers already pass the right price:
    //   • ruta_screen `_updateEntrega` reads override-then-getEffectivePrice
    //     fresh from the DB at write time (the original $5,600→$6,000 fix).
    //   • clientes_screen edit-history dialog uses snapshot-first
    //     (`snapshot > 0 ? snapshot : effective`) so historical rows still
    //     pass their old snapshot back in.
    //   • Zero-qty zero-out callers pass `precioUnitario: 0.0`; harmless
    //     because monto = qty * precio = 0 either way.
    // Trusting the caller is simpler and avoids the orphan-override trap.
    final priceUpdateClause = preserveExistingSnapshot
        ? 'precio_unitario = CASE '
              'WHEN excluded.precio_unitario = 0 OR entregas.precio_unitario > 0 '
              'THEN entregas.precio_unitario '
              'ELSE excluded.precio_unitario '
              'END, '
        : 'precio_unitario = excluded.precio_unitario, ';
    final nowMs = LogicalClock.nextMs();
    final rowFecha = fecha ?? fechaFromDisplayedSemana(semana, diaSemana);
    await transaction(() async {
      // P0.5: stamp updated_at + dirty on every local write so the cloud
      // restore path can tell "local has unsynced changes" from
      // "cloud is newer than local".
      await customStatement(
        'INSERT INTO entregas (cliente_id, reparto_id, producto_id, semana, dia_semana, entregado, devuelto, precio_unitario, fecha, updated_at, dirty) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1) '
        'ON CONFLICT(cliente_id, reparto_id, producto_id, semana, dia_semana) DO UPDATE SET '
        'entregado = excluded.entregado, '
        'devuelto = excluded.devuelto, '
        '$priceUpdateClause'
        'fecha = excluded.fecha, '
        'updated_at = excluded.updated_at, '
        'dirty = 1',
        [
          clienteId,
          repartoId,
          productoId,
          semana,
          diaSemana,
          entregado,
          devuelto,
          precioUnitario,
          rowFecha,
          nowMs,
        ],
      );
      await recalcCuentaCorrienteForCliente(clienteId);
    });
    await recalcAndSaveResumenLive(
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
      coalesce: true,
    );
    onDataChanged?.call();
  }

  /// Explicit user-driven write that changes both today's quantities and the
  /// entrega price snapshot. Normal [setEntrega] preserves nonzero snapshots;
  /// this path is only for "Precio para hoy", where replacing the snapshot is
  /// the requested behavior.
  Future<void> setEntregaWithPrecioUnitarioOverride(
    int clienteId,
    int repartoId,
    int productoId,
    String semana,
    int diaSemana,
    int entregado,
    int devuelto,
    double precioUnitario, {
    // ignore: avoid_init_to_null
    String? fecha = null,
  }) async {
    final nowMs = LogicalClock.nextMs();
    final rowFecha = fecha ?? fechaFromDisplayedSemana(semana, diaSemana);
    await transaction(() async {
      await customStatement(
        'INSERT INTO entregas (cliente_id, reparto_id, producto_id, semana, dia_semana, entregado, devuelto, precio_unitario, fecha, updated_at, dirty) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1) '
        'ON CONFLICT(cliente_id, reparto_id, producto_id, semana, dia_semana) DO UPDATE SET '
        'entregado = excluded.entregado, '
        'devuelto = excluded.devuelto, '
        'precio_unitario = excluded.precio_unitario, '
        'fecha = excluded.fecha, '
        'updated_at = excluded.updated_at, '
        'dirty = 1',
        [
          clienteId,
          repartoId,
          productoId,
          semana,
          diaSemana,
          entregado,
          devuelto,
          precioUnitario,
          rowFecha,
          nowMs,
        ],
      );
      await recalcCuentaCorrienteForCliente(clienteId);
    });
    await recalcAndSaveResumenLive(
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
      coalesce: true,
    );
    onDataChanged?.call();
  }

  Future<List<Entrega>> getEntregasForClient(
    int clienteId,
    int repartoId,
    String semana,
    int diaSemana,
  ) {
    return (select(entregas)..where(
          (t) =>
              t.clienteId.equals(clienteId) &
              t.repartoId.equals(repartoId) &
              t.semana.equals(semana) &
              t.diaSemana.equals(diaSemana),
        ))
        .get();
  }

  Future<Map<int, Map<int, Entrega>>> getEntregasForRepartoDayByCliente(
    int repartoId,
    String semana,
    int diaSemana,
  ) async {
    final rows =
        await (select(entregas)..where(
              (t) =>
                  t.repartoId.equals(repartoId) &
                  t.semana.equals(semana) &
                  t.diaSemana.equals(diaSemana),
            ))
            .get();
    final result = <int, Map<int, Entrega>>{};
    for (final e in rows) {
      result.putIfAbsent(e.clienteId, () => <int, Entrega>{})[e.productoId] = e;
    }
    return result;
  }

  /// Per-product entregado / devuelto totals for a single reparto-day.
  /// Aggregates directly off `entregas` rows — does NOT filter by current
  /// `clientes.dia_semana`, so clientes who were served and then moved to a
  /// different day after the fact still count toward their original day's
  /// totals (the entrega row's own `dia_semana` is the source of truth).
  /// Used by the live-resumen helper and by `home_screen._showCierreSummary`
  /// — single grouped query replaces an N-cliente loop.
  Future<Map<int, ({int entregado, int devuelto})>> getEntregasAggregatedForDay(
    int repartoId,
    String semana,
    int diaSemana,
  ) async {
    final rows = await customSelect(
      'SELECT producto_id, '
      'COALESCE(SUM(entregado), 0) AS te, '
      'COALESCE(SUM(devuelto), 0) AS td '
      'FROM entregas '
      'WHERE reparto_id = ? AND semana = ? AND dia_semana = ? '
      'GROUP BY producto_id',
      variables: [
        Variable.withInt(repartoId),
        Variable.withString(semana),
        Variable.withInt(diaSemana),
      ],
    ).get();
    return {
      for (final r in rows)
        r.read<int>('producto_id'): (
          entregado: r.read<int>('te'),
          devuelto: r.read<int>('td'),
        ),
    };
  }

  /// All entregas for a reparto (all weeks/days). Used for product ranking.
  Future<List<Entrega>> getAllEntregasForReparto(int repartoId) {
    return (select(
      entregas,
    )..where((t) => t.repartoId.equals(repartoId))).get();
  }

  /// All entregas for a specific client in a reparto, ordered by week desc.
  Future<List<Entrega>> getAllEntregasForClient(int clienteId, int repartoId) {
    return (select(entregas)
          ..where(
            (t) =>
                t.clienteId.equals(clienteId) & t.repartoId.equals(repartoId),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.semana),
            (t) => OrderingTerm.desc(t.diaSemana),
          ]))
        .get();
  }

  /// Products in client's possession: total entregado - total devuelto per product (unreturned containers).
  Future<Map<int, int>> getProductosEnLaCalle(
    int clienteId,
    int repartoId,
  ) async {
    final rows = await customSelect(
      'SELECT producto_id, SUM(entregado) - SUM(devuelto) AS neto '
      'FROM entregas WHERE cliente_id = ? AND reparto_id = ? '
      'GROUP BY producto_id HAVING neto > 0',
      variables: [Variable.withInt(clienteId), Variable.withInt(repartoId)],
    ).get();
    return {
      for (final r in rows) r.read<int>('producto_id'): r.read<int>('neto'),
    };
  }

  /// All pagos for a specific client in a reparto, ordered by week desc.
  Future<List<Pago>> getAllPagosForClient(int clienteId, int repartoId) {
    return (select(pagos)
          ..where(
            (t) =>
                t.clienteId.equals(clienteId) & t.repartoId.equals(repartoId),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.semana),
            (t) => OrderingTerm.desc(t.diaSemana),
          ]))
        .get();
  }

  // --- Pagos ---

  Future<Pago?> getPago(
    int clienteId,
    int repartoId,
    String semana,
    int diaSemana,
  ) async {
    final results =
        await (select(pagos)
              ..where(
                (t) =>
                    t.clienteId.equals(clienteId) &
                    t.repartoId.equals(repartoId) &
                    t.semana.equals(semana) &
                    t.diaSemana.equals(diaSemana),
              )
              ..limit(1))
            .get();
    return results.isEmpty ? null : results.first;
  }

  Future<Map<int, Pago>> getPagosForRepartoDayByCliente(
    int repartoId,
    String semana,
    int diaSemana,
  ) async {
    final rows =
        await (select(pagos)..where(
              (t) =>
                  t.repartoId.equals(repartoId) &
                  t.semana.equals(semana) &
                  t.diaSemana.equals(diaSemana),
            ))
            .get();
    return {for (final p in rows) p.clienteId: p};
  }

  Future<void> setPago(
    int clienteId,
    int repartoId,
    String semana,
    int diaSemana,
    String metodoPago,
    double monto, {
    // ignore: avoid_init_to_null
    String? fecha = null,
  }) async {
    // Atomic UPSERT + cuenta_corriente recalc inside a single transaction.
    final nowMs = LogicalClock.nextMs();
    final rowFecha = fecha ?? fechaFromDisplayedSemana(semana, diaSemana);
    await transaction(() async {
      await customStatement(
        'INSERT INTO pagos (cliente_id, reparto_id, semana, dia_semana, metodo_pago, monto, fecha, updated_at, dirty) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1) '
        'ON CONFLICT(cliente_id, reparto_id, semana, dia_semana) DO UPDATE SET '
        'metodo_pago = excluded.metodo_pago, '
        'monto = excluded.monto, '
        'fecha = excluded.fecha, '
        'updated_at = excluded.updated_at, '
        'dirty = 1',
        [
          clienteId,
          repartoId,
          semana,
          diaSemana,
          metodoPago,
          monto,
          rowFecha,
          nowMs,
        ],
      );
      await recalcCuentaCorrienteForCliente(clienteId);
    });
    await recalcAndSaveResumenLive(
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
      coalesce: true,
    );
    onDataChanged?.call();
  }

  Future<void> deleteEntregasForDay(
    int clienteId,
    int repartoId,
    String semana,
    int diaSemana, {
    String? userId,
  }) async {
    // Atomic delete + recalc. Without the recalc, clientes.cuenta_corriente
    // would still reflect the deleted entregas after the row goes away
    // (stale by the deleted amounts). Bug surfaced on Saltar / undo flows.
    await transaction(() async {
      if (userId != null) {
        final rows =
            await (select(entregas)..where(
                  (t) =>
                      t.clienteId.equals(clienteId) &
                      t.repartoId.equals(repartoId) &
                      t.semana.equals(semana) &
                      t.diaSemana.equals(diaSemana),
                ))
                .get();
        for (final r in rows) {
          await markPendingDeletion('entregas', r.id, userId);
        }
      }
      await (delete(entregas)..where(
            (t) =>
                t.clienteId.equals(clienteId) &
                t.repartoId.equals(repartoId) &
                t.semana.equals(semana) &
                t.diaSemana.equals(diaSemana),
          ))
          .go();
      await recalcCuentaCorrienteForCliente(clienteId);
    });
    await recalcAndSaveResumenLive(
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
      coalesce: true,
    );
    onDataChanged?.call();
  }

  Future<void> deletePago(
    int clienteId,
    int repartoId,
    String semana,
    int diaSemana, {
    String? userId,
  }) async {
    // Atomic delete + recalc — same reason as deleteEntregasForDay.
    await transaction(() async {
      if (userId != null) {
        final rows =
            await (select(pagos)..where(
                  (t) =>
                      t.clienteId.equals(clienteId) &
                      t.repartoId.equals(repartoId) &
                      t.semana.equals(semana) &
                      t.diaSemana.equals(diaSemana),
                ))
                .get();
        for (final r in rows) {
          await markPendingDeletion('pagos', r.id, userId);
        }
      }
      await (delete(pagos)..where(
            (t) =>
                t.clienteId.equals(clienteId) &
                t.repartoId.equals(repartoId) &
                t.semana.equals(semana) &
                t.diaSemana.equals(diaSemana),
          ))
          .go();
      await recalcCuentaCorrienteForCliente(clienteId);
    });
    await recalcAndSaveResumenLive(
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
      coalesce: true,
    );
    onDataChanged?.call();
  }

  /// All pagos for a reparto (all weeks/days). Used for sync.
  Future<List<Pago>> getPagosForReparto(int repartoId) {
    return (select(pagos)..where((t) => t.repartoId.equals(repartoId))).get();
  }

  /// All carga entries for a reparto. Used for sync.
  Future<List<CargaDiariaData>> getCargaForReparto(int repartoId) {
    return (select(
      cargaDiaria,
    )..where((t) => t.repartoId.equals(repartoId))).get();
  }

  /// All carga entries for a reparto as raw maps (includes remanente). Used for sync.
  Future<List<Map<String, dynamic>>> getCargaForRepartoRaw(
    int repartoId,
  ) async {
    final rows = await customSelect(
      'SELECT * FROM carga_diaria WHERE reparto_id = ?',
      variables: [Variable(repartoId)],
    ).get();
    return rows
        .map(
          (r) => {
            'id': r.read<int>('id'),
            'producto_id': r.read<int>('producto_id'),
            'reparto_id': r.read<int>('reparto_id'),
            'dia_semana': r.read<int>('dia_semana'),
            'semana': r.read<String>('semana'),
            'cantidad': r.read<int>('cantidad'),
            'remanente': r.read<int>('remanente'),
          },
        )
        .toList();
  }

  /// Get all pagos for a reparto on a specific day/week
  Future<List<Pago>> getPagosForDay(
    int repartoId,
    String semana,
    int diaSemana,
  ) {
    return (select(pagos)..where(
          (t) =>
              t.repartoId.equals(repartoId) &
              t.semana.equals(semana) &
              t.diaSemana.equals(diaSemana),
        ))
        .get();
  }

  /// Get all pagos for a reparto on last week's same day (última vez)
  Future<List<Pago>> getPagosForLastWeek(
    int repartoId,
    String lastWeekStr,
    int diaSemana,
  ) {
    return getPagosForDay(repartoId, lastWeekStr, diaSemana);
  }

  // --- Carga (scoped by reparto) ---

  Future<void> setCantidad(
    int repartoId,
    int productoId,
    int diaSemana,
    String semana,
    int cantidad, {
    int remanente = 0,
    // ignore: avoid_init_to_null
    String? fecha = null,
  }) async {
    // Issue 3: atomic UPSERT against the (reparto_id, producto_id, dia_semana,
    // semana) UNIQUE index added in the v46 migration. Replaces the v30
    // SELECT-then-INSERT/UPDATE which raced under sync — two phones writing
    // concurrently could each pass the SELECT-not-found check and each
    // INSERT, creating duplicate rows that compounded over time.
    // P0.5: stamp updated_at + dirty for cloud-restore freshness checks.
    final nowMs = LogicalClock.nextMs();
    final rowFecha = fecha ?? fechaFromDisplayedSemana(semana, diaSemana);
    await customStatement(
      'INSERT INTO carga_diaria (producto_id, reparto_id, dia_semana, semana, cantidad, remanente, fecha, updated_at, dirty, pending_push_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?) '
      'ON CONFLICT(reparto_id, producto_id, dia_semana, semana) DO UPDATE SET '
      'cantidad = excluded.cantidad, '
      'remanente = excluded.remanente, '
      'fecha = excluded.fecha, '
      'updated_at = excluded.updated_at, '
      'dirty = 1, '
      'pending_push_id = COALESCE(carga_diaria.pending_push_id, excluded.pending_push_id)',
      [
        productoId,
        repartoId,
        diaSemana,
        semana,
        cantidad,
        remanente,
        rowFecha,
        nowMs,
        UidGen.next(),
      ],
    );
    await recalcAndSaveResumenLive(
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
      coalesce: true,
    );
    await recomputeResumenGastosFromCarga(
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
      notify: false,
    );
    onDataChanged?.call();
  }

  // --- Resumenes ---

  Future<int> createResumen({
    required int repartoId,
    required String fecha,
    required String semana,
    required int diaSemana,
    required int duracionSegundos,
    required double efectivo,
    required double transferencia,
    required double cuentaCorriente,
    required double gastos,
    required double sueldoBruto,
    required double sueldoNeto,
    required String productosJson,
    required String gastosJson,
  }) async {
    final id = await into(resumenes).insert(
      ResumenesCompanion.insert(
        repartoId: repartoId,
        fecha: fecha,
        semana: semana,
        diaSemana: diaSemana,
        duracionSegundos: duracionSegundos,
        efectivo: Value(efectivo),
        transferencia: Value(transferencia),
        cuentaCorriente: Value(cuentaCorriente),
        gastos: Value(gastos),
        sueldoBruto: Value(sueldoBruto),
        sueldoNeto: Value(sueldoNeto),
        productosJson: Value(productosJson),
        gastosJson: Value(gastosJson),
        createdAt: Value(DateTime.now().toIso8601String()),
      ),
    );
    // v52: stamp dirty so the new resumen pushes on the next sync.
    await _stampResumenDirty(id);
    onDataChanged?.call();
    return id;
  }

  /// Stamps `dirty = 1` + `updated_at = nowMs` on a resumenes row.
  Future<void> _stampResumenDirty(int resumenId) async {
    await customStatement(
      'UPDATE resumenes SET dirty = 1, updated_at = ? WHERE id = ?',
      [LogicalClock.nextMs(), resumenId],
    );
  }

  Future<List<Resumene>> getResumenesForReparto(int repartoId) {
    return (select(resumenes)
          ..where(
            (t) =>
                t.repartoId.equals(repartoId) &
                t.duracionSegundos.isBiggerThanValue(0),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.fecha),
          ]))
        .get();
  }

  /// Get the most recent finalized resumen for a specific route day (for "última vez" stats).
  /// Excludes [excludeFecha] (today) so it returns the *previous* occurrence.
  Future<Resumene?> getLastResumenForDay(
    int repartoId,
    int diaSemana, {
    String? excludeFecha,
  }) {
    return (select(resumenes)
          ..where((t) {
            var cond =
                t.repartoId.equals(repartoId) &
                t.diaSemana.equals(diaSemana) &
                t.duracionSegundos.isBiggerThanValue(0);
            if (excludeFecha != null) {
              cond = cond & t.fecha.equals(excludeFecha).not();
            }
            return cond;
          })
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.fecha),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get the most recent resumen for a route (any day) — for "última vez" stats.
  /// Excludes [excludeFecha] (today) so it returns the *previous* recorrido, not the current one.
  Future<Resumene?> getLastResumenForReparto(
    int repartoId, {
    String? excludeFecha,
  }) {
    return (select(resumenes)
          ..where((t) {
            var cond =
                t.repartoId.equals(repartoId) &
                t.duracionSegundos.isBiggerThanValue(0);
            if (excludeFecha != null) {
              cond = cond & t.fecha.equals(excludeFecha).not();
            }
            return cond;
          })
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.fecha),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// P3.2: deletes ONLY the resumen row. Entregas, pagos, and carga_diaria
  /// for the day are preserved — historial is sacred. Soderos who want to
  /// wipe a day's entries must do it explicitly per cliente via "Saltar"
  /// or by editing/deleting individual historial entries. The shift summary
  /// is removed; the underlying business records stay.
  Future<void> deleteResumen(Resumene resumen, {String? userId}) async {
    await transaction(() async {
      if (userId != null) {
        await markPendingDeletionWithKey('resumenes', resumen.id, userId, {
          'reparto_id': resumen.repartoId,
          'fecha': resumen.fecha,
          'dia_semana': resumen.diaSemana,
        });
      }
      await (delete(resumenes)..where((t) => t.id.equals(resumen.id))).go();
    });
    onDataChanged?.call();
  }

  /// Update gastos on an existing resumen (gastos total, gastosJson, and recalculate sueldos).
  /// P1.4: uses the shared computeSueldo helper so this matches cierre_screen
  /// and resumen_historial_screen. Old inline formulas were wrong (bruto
  /// subtracted gastos; neto didn't subtract cuenta_corriente).
  Future<void> updateResumenGastos(
    int resumenId,
    double newGastos,
    String newGastosJson,
  ) async {
    final r = await (select(
      resumenes,
    )..where((t) => t.id.equals(resumenId))).getSingle();
    final s = computeSueldo(
      efectivo: r.efectivo,
      transferencia: r.transferencia,
      cuentaCorriente: r.cuentaCorriente,
      gastos: newGastos,
    );
    await (update(resumenes)..where((t) => t.id.equals(resumenId))).write(
      ResumenesCompanion(
        gastos: Value(newGastos),
        gastosJson: Value(newGastosJson),
        sueldoBruto: Value(s.bruto),
        sueldoNeto: Value(s.neto),
      ),
    );
    // v52: stamp dirty so the gastos edit propagates to cloud.
    await _stampResumenDirty(resumenId);
    onDataChanged?.call();
  }

  List<Map<String, dynamic>>? _manualGastosFromJson(String raw) {
    if (raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final item in decoded)
          if (item is Map && item['type'] != 'producto')
            Map<String, dynamic>.from(item),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _productGastosForCarga({
    required int repartoId,
    required String semana,
    required int diaSemana,
  }) async {
    if (!await getCargaGastosEnabled()) return <Map<String, dynamic>>[];
    final products = await getAllProducts(repartoId);
    final cargaData = await getCargaForDayWithRemanente(
      repartoId,
      diaSemana,
      semana,
    );
    final packSizes = await getProductoPackSizesForReparto(repartoId);
    final result = <Map<String, dynamic>>[];
    for (final p in products) {
      final qty = cargaData[p.id]?.cantidad ?? 0;
      final rem = cargaData[p.id]?.remanente ?? 0;
      final packSize = packSizes[p.id] ?? 1;
      final effectivePackSize = packSize >= 2 ? packSize : 1;
      // remanente is stored in PACKS; convert to units (× packSize) before
      // subtracting from the unit-based cantidad. Mirrors home_screen._productGastos.
      final newlyPurchased = (qty - rem * effectivePackSize).clamp(0, qty);
      if (newlyPurchased <= 0 || p.precio <= 0) continue;
      result.add({
        'descripcion': '${p.nombre} (x$newlyPurchased)',
        'monto': p.precio * newlyPurchased / effectivePackSize,
        'type': 'producto',
        'producto_id': p.id,
        'v': 2,
      });
    }
    return result;
  }

  Future<({double total, String json})?> _buildCargaAwareGastos({
    required Resumene resumen,
    required int repartoId,
    required String semana,
    required int diaSemana,
  }) async {
    final manual = _manualGastosFromJson(resumen.gastosJson);
    if (manual == null) return null;
    final product = await _productGastosForCarga(
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
    );
    final all = [...product, ...manual];
    final total = all.fold<double>(
      0,
      (sum, gasto) => sum + ((gasto['monto'] as num?)?.toDouble() ?? 0),
    );
    return (total: total, json: jsonEncode(all));
  }

  Future<void> recomputeResumenGastosFromCarga({
    required int repartoId,
    required String semana,
    required int diaSemana,
    bool notify = true,
  }) async {
    final resumen =
        await (select(resumenes)
              ..where(
                (t) =>
                    t.repartoId.equals(repartoId) &
                    t.semana.equals(semana) &
                    t.diaSemana.equals(diaSemana),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (resumen == null) return;
    final next = await _buildCargaAwareGastos(
      resumen: resumen,
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
    );
    if (next == null) return;
    if (resumen.gastosJson == next.json && resumen.gastos == next.total) {
      return;
    }
    final s = computeSueldo(
      efectivo: resumen.efectivo,
      transferencia: resumen.transferencia,
      cuentaCorriente: resumen.cuentaCorriente,
      gastos: next.total,
    );
    await (update(resumenes)..where((t) => t.id.equals(resumen.id))).write(
      ResumenesCompanion(
        gastos: Value(next.total),
        gastosJson: Value(next.json),
        sueldoBruto: Value(s.bruto),
        sueldoNeto: Value(s.neto),
      ),
    );
    await _stampResumenDirty(resumen.id);
    if (notify) onDataChanged?.call();
  }

  Future<void> recomputeAllResumenGastosFromCarga({bool notify = true}) async {
    final allResumenes = await select(resumenes).get();
    for (final resumen in allResumenes) {
      final next = await _buildCargaAwareGastos(
        resumen: resumen,
        repartoId: resumen.repartoId,
        semana: resumen.semana,
        diaSemana: resumen.diaSemana,
      );
      if (next == null) continue;
      if (resumen.gastosJson == next.json && resumen.gastos == next.total) {
        continue;
      }
      final s = computeSueldo(
        efectivo: resumen.efectivo,
        transferencia: resumen.transferencia,
        cuentaCorriente: resumen.cuentaCorriente,
        gastos: next.total,
      );
      await (update(resumenes)..where((t) => t.id.equals(resumen.id))).write(
        ResumenesCompanion(
          gastos: Value(next.total),
          gastosJson: Value(next.json),
          sueldoBruto: Value(s.bruto),
          sueldoNeto: Value(s.neto),
        ),
      );
      await _stampResumenDirty(resumen.id);
    }
    if (notify) onDataChanged?.call();
  }

  /// Get today's resumen for a given reparto+day+week, or create an empty one.
  /// Get today's resumen if it exists (read-only, does NOT create).
  Future<Resumene?> getResumenForDate({
    required int repartoId,
    required String fecha,
    int? diaSemana,
  }) {
    return (select(resumenes)
          ..where(
            (t) =>
                t.repartoId.equals(repartoId) &
                t.fecha.equals(fecha) &
                (diaSemana == null
                    ? const Constant(true)
                    : t.diaSemana.equals(diaSemana)),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Resumene> getOrCreateTodayResumen({
    required int repartoId,
    required String fecha,
    required String semana,
    required int diaSemana,
  }) async {
    // P1-8 / v81 (audit #8): atomic get-or-create. The old SELECT-then-
    // INSERT raced (double-tap, concurrent recalc) and created duplicate
    // rows for the same day; INSERT ... ON CONFLICT DO NOTHING against the
    // resumenes_nk unique index makes creation idempotent, and the whole
    // flow runs in one transaction.
    var inserted = false;
    late Resumene row;
    await transaction(() async {
      // v85 final audit (money): WEEK-SLOT convergence. entregas/pagos
      // key by (reparto, semana, dia_semana) — a resumen is the rollup
      // of that slot. If the slot ALREADY holds a resumen under a
      // DIFFERENT fecha (día 4 run early on Thursday, then touched again
      // on the real Friday), creating a second row would re-aggregate
      // the SAME slot-keyed entregas and double-count the day in
      // finanzas. Continue the existing slot resumen instead — every
      // resolution path (home ensure/cierre, live recalc) funnels
      // through here, so this is the single choke point.
      final slot = await customSelect(
        'SELECT id, fecha FROM resumenes '
        'WHERE reparto_id = ? AND semana = ? AND dia_semana = ? '
        'ORDER BY updated_at DESC, id DESC LIMIT 1',
        variables: [
          Variable.withInt(repartoId),
          Variable.withString(semana),
          Variable.withInt(diaSemana),
        ],
      ).get();
      if (slot.isNotEmpty && slot.first.read<String>('fecha') != fecha) {
        row =
            await (select(resumenes)
                  ..where((t) => t.id.equals(slot.first.read<int>('id')))
                  ..limit(1))
                .getSingle();
        return;
      }
      await customStatement(
        'INSERT INTO resumenes '
        '(reparto_id, fecha, semana, dia_semana, duracion_segundos, '
        'created_at) VALUES (?, ?, ?, ?, 0, ?) '
        'ON CONFLICT(reparto_id, fecha, dia_semana) DO NOTHING',
        [repartoId, fecha, semana, diaSemana, DateTime.now().toIso8601String()],
      );
      final existing =
          await (select(resumenes)
                ..where(
                  (t) =>
                      t.repartoId.equals(repartoId) &
                      t.fecha.equals(fecha) &
                      t.diaSemana.equals(diaSemana),
                )
                ..limit(1))
              .getSingle();
      // F4: a freshly-inserted resumen has dirty=0 / updated_at=0 from the
      // column defaults — stamp it so the next sync push includes it. The
      // raw-SQL updated_at column isn't on the Drift row type, so detect
      // "just created" via the unstamped duracion+created marker instead:
      // an existing row keeps its prior stamps either way because
      // _stampResumenDirty only runs on the branches below.
      if (existing.semana != semana) {
        await (update(resumenes)..where((t) => t.id.equals(existing.id))).write(
          ResumenesCompanion(semana: Value(semana)),
        );
        await _stampResumenDirty(existing.id);
        inserted = true;
        row =
            (await (select(resumenes)
                  ..where((t) => t.id.equals(existing.id))
                  ..limit(1))
                .getSingle());
        return;
      }
      // Stamp newly-created rows (updated_at = 0 means the INSERT above
      // actually inserted rather than hit the conflict).
      final stampCheck = await customSelect(
        'SELECT updated_at FROM resumenes WHERE id = ?',
        variables: [Variable.withInt(existing.id)],
      ).get();
      final updatedAt = stampCheck.isEmpty
          ? 0
          : (stampCheck.first.read<int?>('updated_at') ?? 0);
      if (updatedAt == 0) {
        await _stampResumenDirty(existing.id);
        inserted = true;
      }
      row = existing;
    });
    if (inserted) onDataChanged?.call();
    return row;
  }

  /// Continuously keep today's resumen in sync with the live entregas/pagos
  /// state while a recorrido is active, so the row holds real data even if
  /// the sodero never presses "Terminar recorrido". Pressing cierre stays the
  /// authoritative final write — this just makes sure nothing is lost in
  /// between.
  ///
  /// Self-guards: bails unless a recorrido is active for [repartoId] AND the
  /// write's ([semana], [diaSemana]) matches that recorrido's today. Past-day
  /// edits from the historial dialog and writes to other days under the same
  /// reparto won't trigger a recalc or dirty today's row.
  ///
  /// Preserves `gastos` and `gastosJson` (those flow through
  /// [updateResumenGastos] from the home_screen gastos tab and already
  /// auto-save). Recomputes salary from current pagos + preserved gastos.
  ///
  /// Does NOT call `onDataChanged` — the outer mutator that invokes us fires
  /// one notification of its own, which is enough.
  String _resumenLiveKey(int repartoId, String semana, int diaSemana) =>
      '$repartoId|$semana|$diaSemana';

  Future<void> recalcAndSaveResumenLive({
    required int repartoId,
    required String semana,
    required int diaSemana,
    bool coalesce = false,
  }) async {
    if (coalesce) {
      final key = _resumenLiveKey(repartoId, semana, diaSemana);
      _pendingResumenLiveRecalcs[key] = (
        repartoId: repartoId,
        semana: semana,
        diaSemana: diaSemana,
      );
      _resumenLiveRecalcTimers[key]?.cancel();
      _resumenLiveRecalcTimers[key] = Timer(
        const Duration(milliseconds: 250),
        () {
          _resumenLiveRecalcTimers.remove(key);
          unawaited(_runPendingResumenLiveRecalc(key));
        },
      );
      return;
    }

    await _recalcAndSaveResumenLiveNow(
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
    );
  }

  Future<void> _runPendingResumenLiveRecalc(String key) async {
    final args = _pendingResumenLiveRecalcs.remove(key);
    if (args == null) return;
    await _recalcAndSaveResumenLiveNow(
      repartoId: args.repartoId,
      semana: args.semana,
      diaSemana: args.diaSemana,
    );
  }

  Future<void> flushPendingResumenLiveRecalcs() async {
    final keys = _pendingResumenLiveRecalcs.keys.toList();
    if (keys.isEmpty) return;
    for (final key in keys) {
      _resumenLiveRecalcTimers.remove(key)?.cancel();
    }
    await Future.wait(keys.map(_runPendingResumenLiveRecalc));
  }

  Future<void> _recalcAndSaveResumenLiveNow({
    required int repartoId,
    required String semana,
    required int diaSemana,
  }) async {
    final activeList = await getActiveRecorridos();
    Map<String, dynamic>? active;
    for (final e in activeList) {
      if (e['repartoId'] == repartoId && e['day'] == diaSemana) {
        active = e;
        break;
      }
    }
    if (active == null) return;
    final startMillis = active['startMillis'] as int?;
    final activeDay = active['day'] as int?;
    if (startMillis == null || activeDay == null) return;

    final startArg = DateTime.fromMillisecondsSinceEpoch(
      startMillis,
    ).toUtc().subtract(const Duration(hours: 3));
    final activeSemana =
        (active['semana'] as String?) ?? argentinaWeekString(at: startArg);
    final fecha = (active['fecha'] as String?) ?? argFecha(startArg);
    if (semana != activeSemana || diaSemana != activeDay) return;

    final resumen = await getOrCreateTodayResumen(
      repartoId: repartoId,
      fecha: fecha,
      semana: semana,
      diaSemana: diaSemana,
    );

    final pagos = await getPagosForDay(repartoId, semana, diaSemana);
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

    final allProducts = await getAllProducts(repartoId);
    final packSizes = await getProductoPackSizesForReparto(repartoId);
    final cargaData = await getCargaForDayWithRemanente(
      repartoId,
      diaSemana,
      semana,
    );
    final carga = {for (final e in cargaData.entries) e.key: e.value.cantidad};
    // remanente is stored in PACKS; convert to units so 'ret' matches 'sal'/'rec'
    // (units) in the persisted resumen products balance and downstream displays.
    final remanente = {
      for (final e in cargaData.entries)
        e.key: e.value.remanente * (packSizes[e.key] ?? 1),
    };
    final aggregated = await getEntregasAggregatedForDay(
      repartoId,
      semana,
      diaSemana,
    );
    final totalEntregado = {
      for (final e in aggregated.entries) e.key: e.value.entregado,
    };
    final totalDevuelto = {
      for (final e in aggregated.entries) e.key: e.value.devuelto,
    };

    final productsList = allProducts
        .where((p) {
          final sal = carga[p.id] ?? 0;
          final ret = remanente[p.id] ?? 0;
          final rec = totalEntregado[p.id] ?? 0;
          final per = totalDevuelto[p.id] ?? 0;
          return sal > 0 || ret > 0 || rec > 0 || per > 0;
        })
        .map(
          (p) => {
            'nombre': p.nombre,
            'sal': carga[p.id] ?? 0,
            'ret': remanente[p.id] ?? 0,
            'rec': totalEntregado[p.id] ?? 0,
            'per': totalDevuelto[p.id] ?? 0,
            'pack_size': packSizes[p.id],
          },
        )
        .toList();

    // Duration computation, not a dirty stamp — use wall-clock so the
    // logical clock counter isn't advanced by a non-mutation read.
    final duracion =
        (DateTime.now().millisecondsSinceEpoch - startMillis) ~/ 1000;
    final s = computeSueldo(
      efectivo: efectivo,
      transferencia: transferencia,
      cuentaCorriente: cuentaCorriente,
      gastos: resumen.gastos,
    );
    final nextGastos = await _buildCargaAwareGastos(
      resumen: resumen,
      repartoId: repartoId,
      semana: semana,
      diaSemana: diaSemana,
    );
    final gastosTotal = nextGastos?.total ?? resumen.gastos;
    final gastosJson = nextGastos?.json ?? resumen.gastosJson;
    final sueldo = nextGastos == null
        ? s
        : computeSueldo(
            efectivo: efectivo,
            transferencia: transferencia,
            cuentaCorriente: cuentaCorriente,
            gastos: gastosTotal,
          );

    await (update(resumenes)..where((t) => t.id.equals(resumen.id))).write(
      ResumenesCompanion(
        duracionSegundos: Value(duracion),
        efectivo: Value(efectivo),
        transferencia: Value(transferencia),
        cuentaCorriente: Value(cuentaCorriente),
        gastos: Value(gastosTotal),
        gastosJson: Value(gastosJson),
        sueldoBruto: Value(sueldo.bruto),
        sueldoNeto: Value(sueldo.neto),
        productosJson: Value(jsonEncode(productsList)),
      ),
    );
    await _stampResumenDirty(resumen.id);
  }

  /// Update an existing resumen with financial + product data from recorrido.
  Future<void> updateResumenFinancials({
    required int resumenId,
    required int duracionSegundos,
    required double efectivo,
    required double transferencia,
    required double cuentaCorriente,
    required double gastos,
    required double sueldoBruto,
    required double sueldoNeto,
    required String productosJson,
    required String gastosJson,
    int? startMillis,
    int? endMillis,
  }) async {
    await (update(resumenes)..where((t) => t.id.equals(resumenId))).write(
      ResumenesCompanion(
        duracionSegundos: Value(duracionSegundos),
        efectivo: Value(efectivo),
        transferencia: Value(transferencia),
        cuentaCorriente: Value(cuentaCorriente),
        gastos: Value(gastos),
        sueldoBruto: Value(sueldoBruto),
        sueldoNeto: Value(sueldoNeto),
        productosJson: Value(productosJson),
        gastosJson: Value(gastosJson),
      ),
    );
    // v62: write start/end millis (raw-SQL columns, not on the Drift
    // Table class) via customStatement so we don't regenerate .g.dart.
    if (startMillis != null || endMillis != null) {
      await customStatement(
        'UPDATE resumenes SET start_millis = COALESCE(?, start_millis), '
        'end_millis = COALESCE(?, end_millis) WHERE id = ?',
        [startMillis, endMillis, resumenId],
      );
    }
    // v52: stamp dirty so the financial close propagates to cloud.
    await _stampResumenDirty(resumenId);
    onDataChanged?.call();
  }

  /// v62: read the recorrido start/end millis for one resumen. Both
  /// nullable — older rows (pre-v62) and rows saved before the cierre
  /// captured the timestamps will return null for either or both.
  Future<({int? startMillis, int? endMillis})> getResumenRecorridoTimes(
    int resumenId,
  ) async {
    final rows = await customSelect(
      'SELECT start_millis, end_millis FROM resumenes WHERE id = ?',
      variables: [Variable.withInt(resumenId)],
    ).get();
    if (rows.isEmpty) return (startMillis: null, endMillis: null);
    final r = rows.first;
    return (
      startMillis: r.read<int?>('start_millis'),
      endMillis: r.read<int?>('end_millis'),
    );
  }

  Future<String> getResumenSessionsJson(int resumenId) async {
    final rows = await customSelect(
      'SELECT sessions_json FROM resumenes WHERE id = ?',
      variables: [Variable.withInt(resumenId)],
    ).get();
    if (rows.isEmpty) return '[]';
    return rows.first.readNullable<String>('sessions_json') ?? '[]';
  }

  Future<void> appendResumenSession({
    required int resumenId,
    required int startMillis,
    required int endMillis,
  }) async {
    final raw = await getResumenSessionsJson(resumenId);
    final list = (raw.isNotEmpty && raw != '[]')
        ? List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          )
        : <Map<String, dynamic>>[];
    list.add({'startMillis': startMillis, 'endMillis': endMillis});
    await customStatement(
      'UPDATE resumenes SET sessions_json = ? WHERE id = ?',
      [jsonEncode(list), resumenId],
    );
    var totalSeconds = 0;
    for (final session in list) {
      final start = session['startMillis'] as int?;
      final end = session['endMillis'] as int?;
      if (start == null || end == null) continue;
      totalSeconds += (end - start) ~/ 1000;
    }
    await customStatement(
      'UPDATE resumenes SET duracion_segundos = ? WHERE id = ?',
      [totalSeconds, resumenId],
    );
    await _stampResumenDirty(resumenId);
    onDataChanged?.call();
  }

  // --- User Settings ---

  Future<void> ensureUserSettingsRow() async {
    await customStatement(
      "INSERT OR IGNORE INTO user_settings (id, work_days, qr_enabled) VALUES (1, '0,1,2,3,4,5', 0)",
    );
  }

  Future<UserSetting> getSettings() async {
    final result = await (select(
      userSettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (result != null) return result;
    // Create default if missing
    await ensureUserSettingsRow();
    return (select(userSettings)..where((t) => t.id.equals(1))).getSingle();
  }

  // Persistent pending-push counter for cloud-synced user_settings fields.
  // Bumped on every setter write, cleared after successful cloud upsert.
  // Lets the sync service know at launch time that local has unpushed edits
  // so the cloud restore doesn't overwrite them.
  //
  // Phase 2 / v53: the legacy counter still exists for back-compat (callers
  // that didn't migrate to per-section). New setters should call one of the
  // per-section helpers (_markUserSettingsSecureDirty / _markUserSettingsPrefsDirty)
  // so the cloud push only sends the changed columns — avoids the bug where
  // a QR toggle overwrites a sibling device's AFIP token edit (issue #11).
  Future<void> _markUserSettingsDirty() async {
    // Default fallback: route to prefs section. Safer than routing to
    // secure because the worst case (writing a prefs field without the
    // secure flag) merely doesn't push secure — vs. accidentally
    // overwriting a sibling device's AFIP token.
    await _markUserSettingsPrefsDirty();
  }

  /// Phase 2 / v53: mark the AFIP + Mercado Pago section dirty. Kept for
  /// legacy callers/backfills. Prefer [_markUserSettingsMpDirty] or
  /// [_markUserSettingsAfipDirty] so blank clears have section-specific intent.
  Future<void> _markUserSettingsSecureDirty() async {
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty = settings_dirty + 1, '
      'settings_dirty_secure = settings_dirty_secure + 1 '
      'WHERE id = 1',
    );
  }

  Future<void> _markUserSettingsMpDirty() async {
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty = settings_dirty + 1, '
      'settings_dirty_secure = settings_dirty_secure + 1, '
      'settings_dirty_mp = settings_dirty_mp + 1 '
      'WHERE id = 1',
    );
  }

  Future<void> _markUserSettingsAfipDirty() async {
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty = settings_dirty + 1, '
      'settings_dirty_secure = settings_dirty_secure + 1, '
      'settings_dirty_afip = settings_dirty_afip + 1 '
      'WHERE id = 1',
    );
  }

  /// Phase 2 / v53: mark the preferences section dirty. Use from every
  /// non-AFIP, non-MP setter (workdays, qr_enabled, map_enabled, notif
  /// toggles + thresholds, auto_listo_on_pago). Bumps both the legacy
  /// `settings_dirty` and `settings_dirty_prefs`.
  Future<void> _markUserSettingsPrefsDirty() async {
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty = settings_dirty + 1, '
      'settings_dirty_prefs = settings_dirty_prefs + 1 '
      'WHERE id = 1',
    );
  }

  Future<int> getUserSettingsDirtyToken() async {
    final rows = await customSelect(
      'SELECT settings_dirty FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return 0;
    return rows.first.read<int>('settings_dirty');
  }

  /// Phase 2: token for the secure (AFIP + MP) section.
  Future<int> getUserSettingsSecureDirtyToken() async {
    final rows = await customSelect(
      'SELECT settings_dirty_secure FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return 0;
    return rows.first.read<int>('settings_dirty_secure');
  }

  Future<int> getUserSettingsMpDirtyToken() async {
    final rows = await customSelect(
      'SELECT settings_dirty_mp FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return 0;
    return rows.first.read<int>('settings_dirty_mp');
  }

  Future<int> getUserSettingsAfipDirtyToken() async {
    final rows = await customSelect(
      'SELECT settings_dirty_afip FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return 0;
    return rows.first.read<int>('settings_dirty_afip');
  }

  /// Phase 2: token for the prefs (everything else) section.
  Future<int> getUserSettingsPrefsDirtyToken() async {
    final rows = await customSelect(
      'SELECT settings_dirty_prefs FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return 0;
    return rows.first.read<int>('settings_dirty_prefs');
  }

  // Subtract [token] from the counter (clamped at 0). If more writes happened
  // during the push, the counter stays >0 so the next sync cycle re-pushes.
  Future<void> clearUserSettingsDirty(int token) async {
    if (token <= 0) return;
    await customStatement(
      'UPDATE user_settings SET settings_dirty = MAX(0, settings_dirty - ?) WHERE id = 1',
      [token],
    );
  }

  /// Phase 2: clear the secure section counter only.
  Future<void> clearUserSettingsSecureDirty(int token) async {
    if (token <= 0) return;
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty_secure = MAX(0, settings_dirty_secure - ?) '
      'WHERE id = 1',
      [token],
    );
  }

  Future<void> clearUserSettingsMpDirty(int token) async {
    if (token <= 0) return;
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty_mp = MAX(0, settings_dirty_mp - ?) '
      'WHERE id = 1',
      [token],
    );
  }

  Future<void> clearUserSettingsAfipDirty(int token) async {
    if (token <= 0) return;
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty_afip = MAX(0, settings_dirty_afip - ?) '
      'WHERE id = 1',
      [token],
    );
  }

  /// Phase 13 — public wrappers used by SyncService's post-push
  /// confirmation pass. When the cloud reject_stale_update trigger
  /// rejects a user_settings push, the section's dirty counter must
  /// be re-stamped so the next sync cycle retries. Currently the
  /// _markUserSettingsX methods are private; these public wrappers
  /// give the sync layer a typed re-stamp seam without exposing the
  /// underlying SQL UPDATE shape.
  Future<void> restampUserSettingsSecureDirty() =>
      _markUserSettingsSecureDirty();
  Future<void> restampUserSettingsPrefsDirty() => _markUserSettingsPrefsDirty();
  Future<void> restampUserSettingsRecorridoDirtyIfFlagOn() =>
      _markUserSettingsRecorridoDirtyIfFlagOn();

  /// Phase 2: clear the prefs section counter only.
  Future<void> clearUserSettingsPrefsDirty(int token) async {
    if (token <= 0) return;
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty_prefs = MAX(0, settings_dirty_prefs - ?) '
      'WHERE id = 1',
      [token],
    );
  }

  // --- Phase 6 / v56: active recorrido cross-device sync ---
  //
  // Conditional dirty-mark gated by sync_recorrido_enabled. The
  // mutator-call sites in this file (saveActiveRecorridos /
  // saveRecorridoClientStatuses / clearRecorridoForReparto /
  // clearAllRecorridos) call _markUserSettingsRecorridoDirtyIfFlagOn after
  // every write. With the flag OFF, the WHERE clause short-circuits and
  // no counter is bumped — pre-Phase-6 behaviour is preserved bit-for-bit.
  // With the flag ON, the counter increments and the recorrido section
  // pushes on the next sync cycle.
  //
  // The auto-prune inside getActiveRecorridos() deliberately does NOT call
  // this helper: it's local cleanup, not a user edit, and bumping dirty
  // every read would generate spurious cross-device pushes.

  Future<void> _markUserSettingsRecorridoDirtyIfFlagOn() async {
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty = settings_dirty + 1, '
      'settings_dirty_recorrido = settings_dirty_recorrido + 1 '
      'WHERE id = 1 AND sync_recorrido_enabled = 1',
    );
  }

  Future<int> getUserSettingsRecorridoDirtyToken() async {
    final rows = await customSelect(
      'SELECT settings_dirty_recorrido FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return 0;
    return rows.first.read<int>('settings_dirty_recorrido');
  }

  Future<void> clearUserSettingsRecorridoDirty(int token) async {
    if (token <= 0) return;
    await customStatement(
      'UPDATE user_settings SET '
      'settings_dirty_recorrido = MAX(0, settings_dirty_recorrido - ?) '
      'WHERE id = 1',
      [token],
    );
  }

  /// Feature flag — per-device, NOT synced to cloud. Each phone decides
  /// independently whether to participate in recorrido sync.
  Future<bool> getSyncRecorridoEnabled() async {
    final rows = await customSelect(
      'SELECT sync_recorrido_enabled FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return false;
    return rows.first.read<int>('sync_recorrido_enabled') == 1;
  }

  Future<void> setSyncRecorridoEnabled(bool enabled) async {
    await customStatement(
      'UPDATE user_settings SET sync_recorrido_enabled = ? WHERE id = 1',
      [enabled ? 1 : 0],
    );
    onDataChanged?.call();
  }

  /// Read the raw JSON string for active_recorridos_json without the
  /// auto-prune side-effect that getActiveRecorridos() runs. Used by the
  /// push path so we send EXACTLY what's on disk, not a prune-adjusted
  /// version.
  Future<String> getActiveRecorridosJsonRaw() async {
    final rows = await customSelect(
      'SELECT active_recorridos_json FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return '[]';
    return rows.first.read<String>('active_recorridos_json');
  }

  /// Snapshot column. Populated by [applyCloudActiveRecorridosJson] right
  /// before an inbound cloud value overwrites the local one — gives the
  /// UI an "undo" target if we ever wire one up.
  Future<String> getActiveRecorridosJsonPrev() async {
    final rows = await customSelect(
      'SELECT active_recorridos_json_prev FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return '';
    return rows.first.read<String>('active_recorridos_json_prev');
  }

  /// Apply an inbound cloud active_recorridos_json value to local in a
  /// single atomic SQL UPDATE that BOTH snapshots the current value into
  /// `active_recorridos_json_prev` AND writes the new value. The atomicity
  /// matters: an interleaved crash between the snapshot and the apply
  /// would otherwise leave _prev mismatched with the live value.
  ///
  /// Caller MUST have already confirmed sync_recorrido_enabled = 1 and
  /// settings_dirty_recorrido = 0 (no unpushed local edit to protect).
  /// SyncService._restoreUserSettingsFromCloud is the only call site.
  Future<void> applyCloudActiveRecorridosJson(String cloudJson) async {
    await customStatement(
      'UPDATE user_settings SET '
      'active_recorridos_json_prev = active_recorridos_json, '
      'active_recorridos_json = ? '
      'WHERE id = 1',
      [cloudJson],
    );
  }

  // --- Phase 4 / v57: UUID v7 cross-device row identifier ---
  //
  // The `uid` column on every business table is the cross-device
  // collision-proof tiebreaker. Existing autoincrement `id` stays the
  // primary key; `uid` is just a secondary unique-per-user-and-table
  // string the push layer can use as the upsert conflict target when
  // sync_uid_enabled = 1.
  //
  // Mobile generates UUID v7 (sortable, RFC 9562) on demand at push
  // time — see SyncService._ensureUidsBeforePush. Cloud-backfilled uids
  // are v4 from gen_random_uuid(); both shapes coexist in the same
  // column. Local rows that came down from cloud carry cloud's uid via
  // the pull's _propagateUidsFromCloud helper.

  /// Read the per-device feature flag. When ON, push code conflicts on
  /// (user_id, uid) instead of (user_id, id) — which is the bug fix for
  /// silent autoincrement collisions between two offline phones (#9).
  /// Default OFF — soderos see no behaviour change after the v57 upgrade
  /// until they opt in.
  Future<bool> getSyncUidEnabled() async {
    final rows = await customSelect(
      'SELECT sync_uid_enabled FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return false;
    return rows.first.read<int>('sync_uid_enabled') == 1;
  }

  Future<void> setSyncUidEnabled(bool enabled) async {
    await customStatement(
      'UPDATE user_settings SET sync_uid_enabled = ? WHERE id = 1',
      [enabled ? 1 : 0],
    );
    onDataChanged?.call();
  }

  /// Stamp a UUID v7 on [id] in [table] iff the row's uid is currently
  /// null/empty. Idempotent — re-calling on a row that already has a uid
  /// is a no-op (the WHERE clause filters it out). Used by the push
  /// layer's lazy-stamp pass: every row entering a push gets a uid first
  /// so the payload is always honest.
  Future<void> ensureRowUid(String table, int id) async {
    await customStatement(
      'UPDATE $table SET uid = ? '
      "WHERE id = ? AND (uid IS NULL OR uid = '')",
      [UidGen.next(), id],
    );
  }

  /// Propagate a cloud-assigned uid into local. Called from the pull
  /// path AFTER the existing INSERT OR REPLACE has run, so local row
  /// already exists with id matched. UPDATE only — never INSERT, since
  /// the pull's INSERT OR REPLACE handles row creation. We never
  /// overwrite a non-null local uid (the local one might already match
  /// cloud, and if they disagree the most recent push is the source of
  /// truth — we let it propagate the other direction next sync).
  Future<void> propagateUidFromCloud(
    String table,
    int id,
    String cloudUid,
  ) async {
    if (cloudUid.isEmpty) return;
    await customStatement(
      'UPDATE $table SET uid = ? '
      "WHERE id = ? AND (uid IS NULL OR uid = '')",
      [cloudUid, id],
    );
  }

  /// Diagnostic helper for tests: read a row's uid directly.
  Future<String?> getRowUid(String table, int id) async {
    final rows = await customSelect(
      'SELECT uid FROM $table WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.readNullable<String>('uid');
  }

  // --- Pending cloud deletions (tombstones) ---

  Future<void> markPendingDeletion(
    String table,
    int rowId,
    String userId,
  ) async {
    await customStatement(
      'INSERT OR IGNORE INTO pending_deletions (table_name, row_id, created_at, user_id) VALUES (?, ?, ?, ?)',
      [table, rowId, LogicalClock.nextMs(), userId],
    );
  }

  Future<void> markPendingDeletionWithKey(
    String table,
    int rowId,
    String userId,
    Map<String, Object?> key,
  ) async {
    await customStatement(
      'INSERT INTO pending_deletions '
      '(table_name, row_id, created_at, user_id, key_json) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(table_name, row_id) DO UPDATE SET '
      'created_at = excluded.created_at, '
      'user_id = excluded.user_id, '
      'key_json = excluded.key_json',
      [table, rowId, LogicalClock.nextMs(), userId, jsonEncode(key)],
    );
  }

  /// Load pending deletions. When [userId] is provided, only returns rows that
  /// belong to that user OR legacy rows without a user_id (pre-v36). Legacy
  /// rows are processed under the current session to preserve in-flight work.
  Future<List<Map<String, Object?>>> getPendingDeletions({
    String? userId,
  }) async {
    final rows = userId != null
        ? await customSelect(
            'SELECT id, table_name, row_id, key_json FROM pending_deletions '
            'WHERE user_id = ? OR user_id IS NULL ORDER BY id',
            variables: [Variable<String>(userId)],
          ).get()
        : await customSelect(
            'SELECT id, table_name, row_id, key_json '
            'FROM pending_deletions ORDER BY id',
          ).get();
    return rows
        .map(
          (r) => {
            'id': r.read<int>('id'),
            'table_name': r.read<String>('table_name'),
            'row_id': r.read<int>('row_id'),
            'key_json': r.readNullable<String>('key_json'),
          },
        )
        .toList();
  }

  Future<Set<String>> getPendingResumenDeletionKeys() async {
    final rows = await customSelect(
      "SELECT key_json FROM pending_deletions "
      "WHERE table_name = 'resumenes' AND key_json IS NOT NULL",
    ).get();
    final keys = <String>{};
    for (final row in rows) {
      final raw = row.readNullable<String>('key_json');
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final repartoId = decoded['reparto_id'];
        final fecha = decoded['fecha'];
        final diaSemana = decoded['dia_semana'];
        if (repartoId == null || fecha == null || diaSemana == null) {
          continue;
        }
        keys.add('$repartoId|$fecha|$diaSemana');
      } catch (_) {}
    }
    return keys;
  }

  Future<Set<int>> getPendingDeletionIdsForTable(String table) async {
    final rows = await customSelect(
      'SELECT row_id FROM pending_deletions WHERE table_name = ?',
      variables: [Variable.withString(table)],
    ).get();
    return rows.map((r) => r.read<int>('row_id')).toSet();
  }

  Future<void> clearPendingDeletion(String table, int rowId) async {
    await customStatement(
      'DELETE FROM pending_deletions WHERE table_name = ? AND row_id = ?',
      [table, rowId],
    );
  }

  // --- Cloud tombstones — Phase 3 / v54 (idempotency record) ---
  //
  // `tombstones_seen` is the local log of cloud tombstones this device has
  // already applied. Used by SyncService._pullTombstones to skip rows that
  // were already deleted locally (e.g. because we initiated the deletion
  // ourselves, or because a previous pull already processed the row). Avoids
  // burning idempotent DELETE statements on every realtime tick.
  //
  // Pure log table — never updated except via `recordTombstoneSeen` (which
  // does an UPSERT on the composite PK). Never deleted from the client side.
  // (A future cloud-side cleanup of old tombstones could be mirrored locally
  // via `pruneTombstonesSeenBefore`, but that's deferred until we ship the
  // cloud-side cleanup job.)

  Future<void> recordTombstoneSeen({
    required String userId,
    required String tableName,
    required int rowId,
    required int deletedAtMs,
  }) async {
    await customStatement(
      'INSERT INTO tombstones_seen (user_id, table_name, row_id, deleted_at) '
      'VALUES (?, ?, ?, ?) '
      'ON CONFLICT(user_id, table_name, row_id) DO UPDATE SET '
      'deleted_at = MAX(tombstones_seen.deleted_at, excluded.deleted_at)',
      [userId, tableName, rowId, deletedAtMs],
    );
  }

  Future<bool> isTombstoneSeen({
    required String userId,
    required String tableName,
    required int rowId,
  }) async {
    final rows = await customSelect(
      'SELECT 1 FROM tombstones_seen '
      'WHERE user_id = ? AND table_name = ? AND row_id = ? LIMIT 1',
      variables: [
        Variable.withString(userId),
        Variable.withString(tableName),
        Variable.withInt(rowId),
      ],
    ).get();
    return rows.isNotEmpty;
  }

  /// Maintenance helper (also handy for tests): drop tombstone-seen rows older
  /// than [cutoffMs]. The cloud table is the source of truth — once cloud-side
  /// cleanup is in place, devices can prune their local cache too.
  Future<void> pruneTombstonesSeenBefore(int cutoffMs) async {
    await customStatement('DELETE FROM tombstones_seen WHERE deleted_at < ?', [
      cutoffMs,
    ]);
  }

  Future<int?> getLastRepartoId() async {
    final settings = await getSettings();
    return settings.lastRepartoId;
  }

  Future<void> setLastRepartoId(int? repartoId) async {
    await (update(userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(lastRepartoId: Value(repartoId)),
    );
  }

  Future<List<int>> getWorkDays() async {
    final settings = await getSettings();
    return settings.workDays
        .split(',')
        .where((s) => s.isNotEmpty)
        .map((s) => int.parse(s.trim()))
        .toList()
      ..sort();
  }

  Future<void> setWorkDays(List<int> days) async {
    final value = days.map((d) => d.toString()).join(',');
    await (update(userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(workDays: Value(value)),
    );
    await _markUserSettingsDirty();
    onDataChanged?.call();
  }

  Future<bool> getQrEnabled() async {
    final settings = await getSettings();
    return settings.qrEnabled;
  }

  Future<void> setQrEnabled(bool enabled) async {
    await (update(userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(qrEnabled: Value(enabled)),
    );
    await _markUserSettingsDirty();
    onDataChanged?.call();
  }

  /// v48: opt-in "auto-Listo on payment" toggle. Off by default. Stored as a
  /// raw-SQL column on user_settings (not in the Drift Table class — see
  /// CLAUDE.md DB migrations note). Read/write via customSelect/customStatement.
  Future<bool> getAutoListoOnPago() async {
    final rows = await customSelect(
      'SELECT auto_listo_on_pago FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return false;
    return rows.first.read<int>('auto_listo_on_pago') == 1;
  }

  /// v65: subscription paid flag. Cloud-driven — mobile never writes
  /// this column locally except via the pull from Supabase. Default
  /// is false (unpaid); the HomeScreen reminder popup fires until the
  /// cloud admin explicitly marks the sodero paid.
  Future<bool> getSubscriptionPaid() async {
    final rows = await customSelect(
      'SELECT subscription_paid FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return false;
    return rows.first.read<int>('subscription_paid') == 1;
  }

  Future<void> setAutoListoOnPago(bool enabled) async {
    await customStatement(
      'UPDATE user_settings SET auto_listo_on_pago = ? WHERE id = 1',
      [enabled ? 1 : 0],
    );
    await _markUserSettingsDirty();
    onDataChanged?.call();
  }

  Future<bool> getCargaGastosEnabled() async {
    final rows = await customSelect(
      'SELECT carga_gastos_enabled FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return true;
    return rows.first.read<int>('carga_gastos_enabled') == 1;
  }

  Future<void> setCargaGastosEnabled(bool enabled) async {
    await customStatement(
      'UPDATE user_settings SET carga_gastos_enabled = ? WHERE id = 1',
      [enabled ? 1 : 0],
    );
    await _markUserSettingsDirty();
    await recomputeAllResumenGastosFromCarga(notify: false);
    onDataChanged?.call();
  }

  Future<bool> getMapEnabled() async {
    final settings = await getSettings();
    return settings.mapEnabled;
  }

  Future<void> setMapEnabled(bool enabled) async {
    await (update(userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(mapEnabled: Value(enabled)),
    );
    await _markUserSettingsDirty();
    onDataChanged?.call();
  }

  /// v61: which non-essential fields show up on each cliente row in Ruta's
  /// vista rápida. Stored as a CSV of keys on user_settings (raw SQL — see
  /// CLAUDE.md DB migrations note). Local-only preference; not synced.
  static const Set<String> defaultVistaRapidaFields = {
    'saldo',
    'frecuencia',
    'etiquetas',
    'notas',
  };

  Future<Set<String>> getVistaRapidaFields() async {
    final rows = await customSelect(
      'SELECT vista_rapida_fields FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return Set.of(defaultVistaRapidaFields);
    final csv = rows.first.read<String>('vista_rapida_fields');
    if (csv.isEmpty) return <String>{};
    return csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  Future<void> setVistaRapidaFields(Set<String> fields) async {
    final csv = fields.toList().join(',');
    await customStatement(
      'UPDATE user_settings SET vista_rapida_fields = ? WHERE id = 1',
      [csv],
    );
    // Intentionally NOT calling _markUserSettingsDirty(): this is a
    // per-device UI preference, not synced to cloud. Avoids triggering
    // an unnecessary user_settings push (the cloud schema doesn't carry
    // this column).
    onDataChanged?.call();
  }

  // --- Active Recorrido Persistence (multi-recorrido) ---

  Future<void> _activeRecorridosWriteChain = Future.value();

  Future<T> _withActiveRecorridosLock<T>(Future<T> Function() body) {
    final next = _activeRecorridosWriteChain.then((_) async => await body());
    _activeRecorridosWriteChain = next.then((_) {}).catchError((_) {});
    return next;
  }

  /// Save ALL active recorridos as a JSON array.
  /// Each entry: {repartoId, startMillis, day, clientStatuses}
  Future<void> saveActiveRecorridos(String jsonArray) async {
    await _withActiveRecorridosLock(() async {
      await customStatement(
        'UPDATE user_settings SET active_recorridos_json = ? WHERE id = 1',
        [jsonArray],
      );
      // Phase 6: stamp dirty so the next sync includes this recorrido state.
      // No-op when sync_recorrido_enabled = 0 (pre-Phase-6 local-only behaviour).
      await _markUserSettingsRecorridoDirtyIfFlagOn();
    });
  }

  /// Update client statuses for a specific reparto/day recorrido.
  Future<void> saveRecorridoClientStatuses(
    int repartoId,
    int day,
    String clientStatusesJson,
  ) async {
    await _withActiveRecorridosLock(() async {
      final rows = await customSelect(
        'SELECT active_recorridos_json FROM user_settings WHERE id = 1',
      ).get();
      if (rows.isEmpty) return;
      final raw = rows.first.read<String>('active_recorridos_json');
      final list = (raw.isNotEmpty && raw != '[]')
          ? List<Map<String, dynamic>>.from(
              (jsonDecode(raw) as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : <Map<String, dynamic>>[];
      for (final entry in list) {
        if (entry['repartoId'] == repartoId && entry['day'] == day) {
          entry['clientStatuses'] = clientStatusesJson;
          // v85: per-entry status clock — the cross-device merge
          // arbitrates clientStatuses independently of the scalar
          // fields so the actively-marking phone keeps its progress.
          entry['statusTouchMs'] = LogicalClock.nextMs();
          break;
        }
      }
      await customStatement(
        'UPDATE user_settings SET active_recorridos_json = ? WHERE id = 1',
        [jsonEncode(list)],
      );
      await _markUserSettingsRecorridoDirtyIfFlagOn();
    });
  }

  Future<void> mutateActiveRecorridosAtomic(
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> current)
    modifier,
  ) async {
    await _withActiveRecorridosLock(() async {
      final rows = await customSelect(
        'SELECT active_recorridos_json FROM user_settings WHERE id = 1',
      ).get();
      if (rows.isEmpty) return;
      final raw = rows.first.read<String>('active_recorridos_json');
      final list = (raw.isNotEmpty && raw != '[]')
          ? List<Map<String, dynamic>>.from(
              (jsonDecode(raw) as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : <Map<String, dynamic>>[];
      final newList = modifier(list);
      await customStatement(
        'UPDATE user_settings SET active_recorridos_json = ? WHERE id = 1',
        [jsonEncode(newList)],
      );
      await _markUserSettingsRecorridoDirtyIfFlagOn();
    });
  }

  Future<Map<String, dynamic>?> getActiveRecorridoForRepartoAndDay(
    int repartoId,
    int day,
  ) async {
    final list = await getActiveRecorridos();
    for (final entry in list) {
      if (entry['repartoId'] == repartoId && entry['day'] == day) return entry;
    }
    return null;
  }

  /// Get all persisted active recorridos. Returns empty list if none.
  /// Auto-prunes stale ended entries, but preserves unended entries even after
  /// midnight so an overnight recorrido can still be finalized on its start day.
  Future<List<Map<String, dynamic>>> getActiveRecorridos() async {
    final rows = await customSelect(
      'SELECT active_recorridos_json FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return [];
    final raw = rows.first.read<String>('active_recorridos_json');
    if (raw.isEmpty || raw == '[]') return [];
    final list = List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    final now = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;
    list.removeWhere((entry) {
      final ms = entry['startMillis'] as int?;
      if (ms == null) {
        changed = true;
        return true;
      }
      if (entry['cleared'] == true) {
        // v85: cleared soft-tombstones are GC'd by the sync merge after
        // kRecorridoTombstoneRetention — the tombstone must outlive any
        // realistic offline window, or a returning device's UNENDED copy
        // resurrects the cleared day (Codex review). The local physical
        // prune uses the SAME horizon: a shorter one would remove the
        // entry locally only for the next pull-merge to re-import it,
        // churning a rewrite on every read until the cloud GC.
        final stale =
            nowMs - recorridoStatusFreshness(entry) >
            kRecorridoTombstoneRetention.inMilliseconds;
        if (stale) changed = true;
        return stale;
      }
      if (!_isEndedActiveRecorridoEntry(entry)) return false;
      final start = DateTime.fromMillisecondsSinceEpoch(
        ms,
      ).toUtc().subtract(const Duration(hours: 3));
      final stale =
          start.year != now.year ||
          start.month != now.month ||
          start.day != now.day;
      if (stale) changed = true;
      return stale;
    });
    if (changed) {
      await customStatement(
        'UPDATE user_settings SET active_recorridos_json = ? WHERE id = 1',
        [jsonEncode(list)],
      );
    }
    // v85: cleared entries stay in the stored JSON (the merge needs the
    // tombstone) but are INVISIBLE to every caller — a closed shift must
    // not resurface as resumable.
    return list.where((e) => e['cleared'] != true).toList();
  }

  bool _isEndedActiveRecorridoEntry(Map<String, dynamic> entry) {
    final endMillis = entry['endMillis'];
    return endMillis != null && endMillis != 0;
  }

  /// v85: soft-clear ONE (reparto, day) recorrido entry.
  ///
  /// Clears must be SOFT (`cleared: true` + a fresh scalar clock), not a
  /// physical removal: the cross-device merge would resurrect a removed
  /// entry from the cloud copy, re-showing a closed shift. A cleared mark
  /// with fresher scalars out-arbitrates every stale live copy instead,
  /// so the clear propagates. [getActiveRecorridos] filters cleared
  /// entries from its result; the merge GCs them after its retention.
  ///
  /// Day-scoped so the midnight reset / cierre of ONE day can never wipe
  /// a sibling instance's still-running recorrido on the same reparto.
  Future<void> clearRecorridoForRepartoAndDay(int repartoId, int day) async {
    await _withActiveRecorridosLock(() async {
      await _softClearRecorridosWhere(
        (e) => e['repartoId'] == repartoId && e['day'] == day,
      );
    });
  }

  /// Soft-clear ALL of a reparto's recorrido entries (every day). Kept
  /// for the reparto-deletion flow; day-scoped flows must use
  /// [clearRecorridoForRepartoAndDay].
  Future<void> clearRecorridoForReparto(int repartoId) async {
    await _withActiveRecorridosLock(() async {
      await _softClearRecorridosWhere((e) => e['repartoId'] == repartoId);
    });
  }

  /// Shared soft-clear body. MUST be called under the recorridos lock.
  Future<void> _softClearRecorridosWhere(
    bool Function(Map<String, dynamic> entry) match,
  ) async {
    final rows = await customSelect(
      'SELECT active_recorridos_json FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return;
    final raw = rows.first.read<String>('active_recorridos_json');
    final list = (raw.isNotEmpty && raw != '[]')
        ? List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          )
        : <Map<String, dynamic>>[];
    var changed = false;
    for (final entry in list) {
      if (entry['cleared'] == true || !match(entry)) continue;
      entry['cleared'] = true;
      // A cleared entry must also read as ENDED for pre-v85 builds in a
      // mixed-version window (their prune only drops ended-stale entries;
      // an un-ended ghost would show a running chronometer forever).
      final end = entry['endMillis'];
      if (end == null || end == 0) {
        entry['endMillis'] = DateTime.now().millisecondsSinceEpoch;
      }
      entry['lastTouchMs'] = LogicalClock.nextMs();
      changed = true;
    }
    if (!changed) return;
    await customStatement(
      'UPDATE user_settings SET active_recorridos_json = ? WHERE id = 1',
      [jsonEncode(list)],
    );
    await _markUserSettingsRecorridoDirtyIfFlagOn();
  }

  Future<void> markRecorridoSessionEnded(
    int repartoId,
    int day,
    int endMillis,
  ) async {
    await _withActiveRecorridosLock(() async {
      final rows = await customSelect(
        'SELECT active_recorridos_json FROM user_settings WHERE id = 1',
      ).get();
      if (rows.isEmpty) return;
      final raw = rows.first.read<String>('active_recorridos_json');
      final list = (raw.isNotEmpty && raw != '[]')
          ? List<Map<String, dynamic>>.from(
              (jsonDecode(raw) as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : <Map<String, dynamic>>[];
      var changed = false;
      for (final entry in list) {
        if (entry['repartoId'] == repartoId && entry['day'] == day) {
          entry['endMillis'] = endMillis;
          // v85: scalar clock for the cross-device merge.
          entry['lastTouchMs'] = LogicalClock.nextMs();
          changed = true;
          break;
        }
      }
      if (!changed) return;
      await customStatement(
        'UPDATE user_settings SET active_recorridos_json = ? WHERE id = 1',
        [jsonEncode(list)],
      );
      await _markUserSettingsRecorridoDirtyIfFlagOn();
    });
  }

  Future<void> reactivateRecorridoSession(
    int repartoId,
    int day,
    int newStartMillis,
  ) async {
    await _withActiveRecorridosLock(() async {
      final rows = await customSelect(
        'SELECT active_recorridos_json FROM user_settings WHERE id = 1',
      ).get();
      if (rows.isEmpty) return;
      final raw = rows.first.read<String>('active_recorridos_json');
      final list = (raw.isNotEmpty && raw != '[]')
          ? List<Map<String, dynamic>>.from(
              (jsonDecode(raw) as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : <Map<String, dynamic>>[];
      var changed = false;
      for (final entry in list) {
        if (entry['repartoId'] == repartoId && entry['day'] == day) {
          entry['startMillis'] = newStartMillis;
          entry['endMillis'] = null;
          // v85: scalar clock for the cross-device merge.
          entry['lastTouchMs'] = LogicalClock.nextMs();
          changed = true;
          break;
        }
      }
      if (!changed) return;
      await customStatement(
        'UPDATE user_settings SET active_recorridos_json = ? WHERE id = 1',
        [jsonEncode(list)],
      );
      await _markUserSettingsRecorridoDirtyIfFlagOn();
    });
  }

  /// Clear all persisted recorridos. HARD reset to '[]' — only used as
  /// the corrupt-JSON recovery path (home_screen restore catch), where a
  /// soft-clear is impossible because the array can't be decoded. The
  /// next sync merge re-imports the cloud copy, which doubles as the
  /// heal for whatever local corruption triggered this.
  Future<void> clearAllRecorridos() async {
    await customStatement(
      "UPDATE user_settings SET active_recorridos_json = '[]' WHERE id = 1",
    );
    await _markUserSettingsRecorridoDirtyIfFlagOn();
  }

  // --- v85: «Instancias» registry + cross-device merge appliers ---
  //
  // instances_json entries: {id (UUID v7 or "default:<repartoId>"),
  // repartoId, nombre, day (null until picked), createdAtMs, updatedAtMs,
  // deleted?}. The default instance per reparto is IMPLICIT (synthesized
  // by the UI under the stable id "default:<repartoId>") and only gets a
  // stored entry when renamed. Registry and recorrido state ride the
  // same dirty section / sync lock — they mutate together and a torn
  // push of one without the other has no meaning.

  /// Raw column read for the push path — no decode, no side effects.
  Future<String> getInstancesJsonRaw() async {
    final rows = await customSelect(
      'SELECT instances_json FROM user_settings WHERE id = 1',
    ).get();
    if (rows.isEmpty) return '[]';
    return rows.first.read<String>('instances_json');
  }

  /// Decoded registry entries, INCLUDING soft-deleted ones — callers
  /// (UI/web) filter `deleted == true` themselves where it matters.
  Future<List<Map<String, dynamic>>> getInstancesRaw() async {
    return decodeJsonList(await getInstancesJsonRaw());
  }

  /// Atomic read-modify-write over the instances registry. Mirrors
  /// [mutateActiveRecorridosAtomic]: same in-process lock (both JSON
  /// columns serialize together) and the same recorrido-section dirty
  /// stamp so the next sync cycle pushes the edit.
  Future<void> mutateInstancesAtomic(
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> current)
    modifier,
  ) async {
    await _withActiveRecorridosLock(() async {
      final rows = await customSelect(
        'SELECT instances_json FROM user_settings WHERE id = 1',
      ).get();
      if (rows.isEmpty) return;
      final list = decodeJsonList(rows.first.read<String>('instances_json'));
      final newList = modifier(list);
      await customStatement(
        'UPDATE user_settings SET instances_json = ? WHERE id = 1',
        [jsonEncode(newList)],
      );
      await _markUserSettingsRecorridoDirtyIfFlagOn();
    });
  }

  /// Soft-delete every instance of [repartoId] — the reparto-deletion
  /// companion. Soft (not removed) so a sibling device's stale copy
  /// can't resurrect them through the merge; the merge GCs the
  /// tombstones after its retention. Touches NO business data.
  Future<void> purgeInstancesForReparto(int repartoId) async {
    await mutateInstancesAtomic((list) {
      for (final e in list) {
        if (e['repartoId'] == repartoId && e['deleted'] != true) {
          e['deleted'] = true;
          e['updatedAtMs'] = LogicalClock.nextMs();
        }
      }
      return list;
    });
  }

  /// v85 sync seam: merge an inbound cloud `active_recorridos_json` into
  /// local atomically (read + merge + write under the recorridos lock, so
  /// no local mutator can interleave between our read and our write).
  ///
  /// Returns the merged JSON (what the caller should push) and whether it
  /// diverges from what cloud sent (i.e. local contributed something the
  /// cloud row lacks → a push is needed for full convergence).
  ///
  /// Local is only rewritten when the merge actually changed it; the
  /// previous value is snapshotted to active_recorridos_json_prev in the
  /// same atomic UPDATE (same rationale as [applyCloudActiveRecorridosJson]).
  /// Deliberately does NOT stamp the dirty counter — pull callers decide
  /// (divergence → re-stamp + scheduleSyncSoon), push callers upsert the
  /// returned JSON themselves.
  Future<({String merged, bool divergesFromCloud})> mergeCloudActiveRecorridos(
    String cloudJson,
  ) async {
    return _withActiveRecorridosLock(() async {
      final rows = await customSelect(
        'SELECT active_recorridos_json FROM user_settings WHERE id = 1',
      ).get();
      final localRaw = rows.isEmpty
          ? '[]'
          : rows.first.read<String>('active_recorridos_json');
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cloudList = decodeJsonList(cloudJson);
      final localList = decodeJsonList(localRaw);
      // (cloud, local) — local wins exact freshness ties.
      final merged = mergeRecorridos(cloudList, localList, nowMs: nowMs);
      final mergedJson = encodeJsonList(merged);
      if (rows.isNotEmpty && mergedJson != encodeJsonList(localList)) {
        await customStatement(
          'UPDATE user_settings SET '
          'active_recorridos_json_prev = active_recorridos_json, '
          'active_recorridos_json = ? '
          'WHERE id = 1',
          [mergedJson],
        );
      }
      return (
        merged: mergedJson,
        divergesFromCloud: mergedJson != encodeJsonList(cloudList),
      );
    });
  }

  /// v85 sync seam: instances_json twin of [mergeCloudActiveRecorridos].
  Future<({String merged, bool divergesFromCloud})> mergeCloudInstances(
    String cloudJson,
  ) async {
    return _withActiveRecorridosLock(() async {
      final rows = await customSelect(
        'SELECT instances_json FROM user_settings WHERE id = 1',
      ).get();
      final localRaw = rows.isEmpty
          ? '[]'
          : rows.first.read<String>('instances_json');
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cloudList = decodeJsonList(cloudJson);
      final localList = decodeJsonList(localRaw);
      final merged = mergeInstances(cloudList, localList, nowMs: nowMs);
      final mergedJson = encodeJsonList(merged);
      if (rows.isNotEmpty && mergedJson != encodeJsonList(localList)) {
        await customStatement(
          'UPDATE user_settings SET instances_json = ? WHERE id = 1',
          [mergedJson],
        );
      }
      return (
        merged: mergedJson,
        divergesFromCloud: mergedJson != encodeJsonList(cloudList),
      );
    });
  }

  // Legacy single-recorrido methods kept for backward compat during migration
  Future<Map<String, dynamic>?> getRecorridoState() async {
    try {
      final rows = await customSelect(
        'SELECT recorrido_active, recorrido_start_millis, recorrido_reparto_id, '
        'recorrido_day, recorrido_client_statuses FROM user_settings WHERE id = 1',
      ).get();
      if (rows.isEmpty) return null;
      final row = rows.first;
      final active = row.read<int>('recorrido_active') == 1;
      if (!active) return null;
      final startMillis = row.readNullable<int>('recorrido_start_millis');
      final repartoId = row.readNullable<int>('recorrido_reparto_id');
      if (startMillis == null || repartoId == null) return null;
      return {
        'startMillis': startMillis,
        'repartoId': repartoId,
        'day': row.read<int>('recorrido_day'),
        'clientStatuses': row.read<String>('recorrido_client_statuses'),
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clearRecorridoState() async {
    try {
      await customStatement(
        'UPDATE user_settings SET recorrido_active = 0, recorrido_start_millis = NULL, '
        "recorrido_reparto_id = NULL, recorrido_day = -1, recorrido_client_statuses = '' WHERE id = 1",
      );
    } catch (_) {}
  }

  // --- Etiqueta Colors ---

  Future<List<EtiquetaColor>> getEtiquetaColors(int repartoId) {
    return (select(
      etiquetaColors,
    )..where((t) => t.repartoId.equals(repartoId))).get();
  }

  Future<void> setEtiquetaColor(
    int repartoId,
    String nombre,
    String colorHex,
  ) async {
    final existing =
        await (select(etiquetaColors)..where(
              (t) => t.repartoId.equals(repartoId) & t.nombre.equals(nombre),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (update(etiquetaColors)..where((t) => t.id.equals(existing.id)))
          .write(EtiquetaColorsCompanion(colorHex: Value(colorHex)));
    } else {
      await into(etiquetaColors).insert(
        EtiquetaColorsCompanion.insert(
          repartoId: repartoId,
          nombre: nombre,
          colorHex: colorHex,
        ),
      );
    }
    // Phase 10d: etiqueta_colors is local-only (never pushed or pulled).
    // Previous Phase 2-remainder stamped dirty=1 here, but those rows
    // would never be pushed, just accumulating dead state. Removed.
  }

  /// Rename an etiqueta across all clients in a reparto and update its color entry.
  Future<void> renameEtiqueta(
    int repartoId,
    String oldName,
    String newName,
  ) async {
    final clients = await (select(
      clientes,
    )..where((t) => t.repartoId.equals(repartoId))).get();
    final oldLower = oldName.toLowerCase().trim();
    final newTrimmed = newName.trim();
    for (final c in clients) {
      final tags = c.etiqueta
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      bool changed = false;
      for (int i = 0; i < tags.length; i++) {
        if (tags[i].toLowerCase() == oldLower) {
          tags[i] = newTrimmed;
          changed = true;
        }
      }
      if (changed) {
        await (update(clientes)..where((t) => t.id.equals(c.id))).write(
          ClientesCompanion(etiqueta: Value(tags.join(', '))),
        );
        // F4: each renamed cliente's etiqueta needs to sync.
        await _stampClienteDirty(c.id, fields: const {'etiqueta'});
      }
    }
    // Update etiqueta_colors entry
    final existing =
        await (select(etiquetaColors)..where(
              (t) => t.repartoId.equals(repartoId) & t.nombre.equals(oldLower),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (update(
        etiquetaColors,
      )..where((t) => t.id.equals(existing.id))).write(
        EtiquetaColorsCompanion(nombre: Value(newTrimmed.toLowerCase())),
      );
      // Phase 10d: etiqueta_colors is local-only — no dirty stamp needed.
    }
    onDataChanged?.call();
  }

  // --- Deuda Notification Settings ---

  Future<bool> getDeudaNotifEnabled() async {
    final settings = await getSettings();
    return settings.deudaNotifEnabled;
  }

  Future<int> getDeudaNotifWeeks() async {
    final settings = await getSettings();
    return settings.deudaNotifWeeks;
  }

  Future<void> setDeudaNotifEnabled(bool enabled) async {
    await (update(userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(deudaNotifEnabled: Value(enabled)),
    );
    await _markUserSettingsDirty();
    onDataChanged?.call();
  }

  Future<void> setDeudaNotifWeeks(int weeks) async {
    await (update(userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(deudaNotifWeeks: Value(weeks)),
    );
    await _markUserSettingsDirty();
    onDataChanged?.call();
  }

  Future<bool> getAdminMessageBannerEnabled() async {
    final rows = await customSelect(
      'SELECT admin_message_banner_enabled FROM user_settings '
      'WHERE id = 1 LIMIT 1',
    ).get();
    if (rows.isEmpty) return true;
    return rows.first.read<int>('admin_message_banner_enabled') != 0;
  }

  Future<void> setAdminMessageBannerEnabled(bool enabled) async {
    await customStatement(
      'UPDATE user_settings SET admin_message_banner_enabled = ? WHERE id = 1',
      [enabled ? 1 : 0],
    );
    onDataChanged?.call();
  }

  // --- App Notifications ---

  Future<List<AppNotification>> getAllNotifications() {
    return (select(
      appNotifications,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Future<List<AppNotificationWithMessageId>>
  getAllNotificationsWithMessageIds() async {
    final rows = await customSelect(
      'SELECT id, type, title, body, cliente_id, created_at, read, message_id '
      'FROM app_notifications ORDER BY created_at DESC',
      readsFrom: {appNotifications},
    ).get();
    return rows.map(_notificationWithMessageIdFromRow).toList();
  }

  Future<List<AppNotification>> getUnreadNotifications() {
    return (select(appNotifications)
          ..where((t) => t.read.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<void> markNotificationRead(int notifId) async {
    await (update(appNotifications)..where((t) => t.id.equals(notifId))).write(
      const AppNotificationsCompanion(read: Value(true)),
    );
  }

  Future<void> markAllNotificationsRead() async {
    await (update(
      appNotifications,
    )).write(const AppNotificationsCompanion(read: Value(true)));
  }

  Future<void> deleteNotification(int notifId) async {
    await (delete(appNotifications)..where((t) => t.id.equals(notifId))).go();
  }

  Future<int?> getHighestAdminMessageId() async {
    final rows = await customSelect(
      'SELECT MAX(message_id) AS max_message_id '
      'FROM app_notifications WHERE message_id IS NOT NULL',
    ).get();
    if (rows.isEmpty) return null;
    return rows.first.readNullable<int>('max_message_id');
  }

  Future<bool> isAdminMessageDismissed(int messageId) async {
    final rows = await customSelect(
      'SELECT message_id FROM dismissed_admin_messages '
      'WHERE message_id = ? LIMIT 1',
      variables: [Variable.withInt(messageId)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> dismissAdminMessage(int notificationId, int messageId) async {
    await customStatement(
      'INSERT OR IGNORE INTO dismissed_admin_messages '
      '(message_id, dismissed_at) VALUES (?, ?)',
      [messageId, DateTime.now().millisecondsSinceEpoch],
    );
    await deleteNotification(notificationId);
  }

  Future<void> insertAdminMessageNotification({
    required int messageId,
    required String title,
    required String body,
    required String createdAt,
  }) async {
    await customStatement(
      'INSERT OR IGNORE INTO app_notifications '
      '(type, title, body, cliente_id, created_at, read, message_id) '
      'VALUES (?, ?, ?, NULL, ?, 0, ?)',
      ['admin_message', title, body, createdAt, messageId],
    );
    // customStatement NO avisa a los watchers de Drift: sin esto, el
    // contador rojo y el punto verde del bell (streams watchUnread*)
    // no se enteraban del mensaje hasta reabrir la pantalla.
    notifyUpdates({
      TableUpdate.onTable(appNotifications, kind: UpdateKind.insert),
    });
  }

  Future<bool> insertAdminMessageNotificationIfAbsent({
    required int messageId,
    required String title,
    required String body,
    required String createdAt,
  }) async {
    await customStatement(
      'INSERT OR IGNORE INTO app_notifications '
      '(type, title, body, cliente_id, created_at, read, message_id) '
      'VALUES (?, ?, ?, NULL, ?, 0, ?)',
      ['admin_message', title, body, createdAt, messageId],
    );
    final rows = await customSelect('SELECT changes() AS c').get();
    final inserted = rows.first.read<int>('c') > 0;
    if (inserted) {
      // Ver nota en insertAdminMessageNotification: los streams del bell
      // (badge rojo + punto verde) solo se actualizan en vivo si Drift
      // se entera del INSERT crudo.
      notifyUpdates({
        TableUpdate.onTable(appNotifications, kind: UpdateKind.insert),
      });
    }
    return inserted;
  }

  Stream<int> watchUnreadAdminMessageCount() {
    return customSelect(
      "SELECT COUNT(*) AS c FROM app_notifications "
      "WHERE type = 'admin_message' AND read = 0",
      readsFrom: {appNotifications},
    ).watchSingle().map((row) => row.read<int>('c'));
  }

  /// Stream of the total unread notification count across ALL types
  /// (deuda, inactivo, stock_low, admin_message, …). Drives the bell's
  /// number badge so it updates live as new notifications land (sync
  /// pulls, local generation, mark-as-read).
  Stream<int> watchUnreadNotificationCount() {
    return customSelect(
      "SELECT COUNT(*) AS c FROM app_notifications WHERE read = 0",
      readsFrom: {appNotifications},
    ).watchSingle().map((row) => row.read<int>('c'));
  }

  Future<AppNotificationWithMessageId?> getNotificationByMessageId(
    int messageId,
  ) async {
    final rows = await customSelect(
      'SELECT id, type, title, body, cliente_id, created_at, read, message_id '
      'FROM app_notifications WHERE message_id = ? LIMIT 1',
      variables: [Variable.withInt(messageId)],
      readsFrom: {appNotifications},
    ).get();
    if (rows.isEmpty) return null;
    return _notificationWithMessageIdFromRow(rows.first);
  }

  AppNotificationWithMessageId _notificationWithMessageIdFromRow(QueryRow row) {
    return AppNotificationWithMessageId(
      notification: AppNotification(
        id: row.read<int>('id'),
        type: row.read<String>('type'),
        title: row.read<String>('title'),
        body: row.read<String>('body'),
        clienteId: row.readNullable<int>('cliente_id'),
        createdAt: row.read<String>('created_at'),
        read: row.read<bool>('read'),
      ),
      messageId: row.readNullable<int>('message_id'),
    );
  }

  /// Check if a deuda notification already exists for a given client.
  Future<bool> hasDeudaNotification(int clienteId) async {
    return hasNotificationForClient(clienteId, 'deuda_weeks');
  }

  Future<bool> hasNotificationForClient(int clienteId, String type) async {
    final results =
        await (select(appNotifications)
              ..where(
                (t) => t.type.equals(type) & t.clienteId.equals(clienteId),
              )
              ..limit(1))
            .get();
    return results.isNotEmpty;
  }

  /// Check if a notification type was dismissed for a client.
  Future<bool> isNotifDismissed(int clienteId, String type) async {
    final existing =
        await (select(notifDismissals)..where(
              (t) => t.clienteId.equals(clienteId) & t.type.equals(type),
            ))
            .getSingleOrNull();
    return existing != null;
  }

  /// Record a dismissal for a client + notification type.
  Future<void> dismissNotif(int clienteId, String type) async {
    if (await isNotifDismissed(clienteId, type)) return;
    await into(
      notifDismissals,
    ).insert(NotifDismissalsCompanion.insert(clienteId: clienteId, type: type));
  }

  /// Clear a dismissal (when condition resets, allowing re-notification).
  Future<void> clearNotifDismissal(int clienteId, String type) async {
    await (delete(
      notifDismissals,
    )..where((t) => t.clienteId.equals(clienteId) & t.type.equals(type))).go();
  }

  // --- Inactive Notification Settings ---

  Future<bool> getInactiveNotifEnabled() async {
    final settings = await getSettings();
    return settings.inactiveNotifEnabled;
  }

  Future<int> getInactiveNotifWeeks() async {
    final settings = await getSettings();
    return settings.inactiveNotifWeeks;
  }

  Future<void> setInactiveNotifEnabled(bool enabled) async {
    await (update(userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(inactiveNotifEnabled: Value(enabled)),
    );
    await _markUserSettingsDirty();
    onDataChanged?.call();
  }

  Future<void> setInactiveNotifWeeks(int weeks) async {
    await (update(userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(inactiveNotifWeeks: Value(weeks)),
    );
    await _markUserSettingsDirty();
    onDataChanged?.call();
  }

  Future<void> addNotification({
    required String type,
    required String title,
    required String body,
    int? clienteId,
  }) async {
    await into(appNotifications).insert(
      AppNotificationsCompanion.insert(
        type: type,
        title: title,
        body: body,
        clienteId: Value(clienteId),
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  // --- Stock Low Notification Settings ---

  Future<bool> getStockNotifMasterEnabled() async {
    final settings = await getSettings();
    return settings.stockNotifMasterEnabled;
  }

  Future<void> setStockNotifMasterEnabled(bool enabled) async {
    await (update(userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(stockNotifMasterEnabled: Value(enabled)),
    );
    await _markUserSettingsDirty();
    onDataChanged?.call();
  }

  /// Ensure every product has a stock notif settings row.
  Future<void> ensureStockNotifSettingsExist(int repartoId) async {
    final allProds = await getAllProducts(repartoId);
    final existing = await (select(
      stockNotifSettings,
    )..where((t) => t.repartoId.equals(repartoId))).get();
    final existingIds = existing.map((e) => e.productoId).toSet();
    for (final p in allProds) {
      if (!existingIds.contains(p.id)) {
        final id = await into(stockNotifSettings).insert(
          StockNotifSettingsCompanion.insert(
            productoId: p.id,
            repartoId: Value(repartoId),
            enabled: const Value(true),
            threshold: const Value(5),
          ),
        );
        await stampRowDirty('stock_notif_settings', id);
      }
    }
  }

  Future<List<StockNotifSetting>> getAllStockNotifSettings(
    int repartoId,
  ) async {
    return (select(
      stockNotifSettings,
    )..where((t) => t.repartoId.equals(repartoId))).get();
  }

  Future<List<StockNotifSetting>> getAllStockNotifSettingsAll() async {
    return select(stockNotifSettings).get();
  }

  Future<StockNotifSetting?> getStockNotifSetting(int productoId) async {
    return (select(
      stockNotifSettings,
    )..where((t) => t.productoId.equals(productoId))).getSingleOrNull();
  }

  Future<void> setStockNotifEnabled(int productoId, bool enabled) async {
    await (update(stockNotifSettings)
          ..where((t) => t.productoId.equals(productoId)))
        .write(StockNotifSettingsCompanion(enabled: Value(enabled)));
    await stampStockNotifDirty(productoId);
    onDataChanged?.call();
  }

  Future<void> setStockNotifThreshold(int productoId, int threshold) async {
    await (update(stockNotifSettings)
          ..where((t) => t.productoId.equals(productoId)))
        .write(StockNotifSettingsCompanion(threshold: Value(threshold)));
    await stampStockNotifDirty(productoId);
    onDataChanged?.call();
  }

  // ─── Habitual product settings ───

  Future<void> ensureHabitualSettingsExist(int repartoId) async {
    final allProds = await getAllProducts(repartoId);
    final existing = await customSelect(
      'SELECT producto_id FROM habitual_product_settings WHERE reparto_id = ?',
      variables: [Variable.withInt(repartoId)],
    ).get();
    final existingIds = existing.map((r) => r.read<int>('producto_id')).toSet();
    for (final p in allProds) {
      if (!existingIds.contains(p.id)) {
        // Insert with dirty/updated_at populated in the same statement so
        // a crash between insert+stamp can't leave the row un-pushable.
        await customInsert(
          'INSERT INTO habitual_product_settings '
          '(reparto_id, producto_id, enabled, dirty, updated_at) '
          'VALUES (?, ?, 1, 1, ?)',
          variables: [
            Variable.withInt(repartoId),
            Variable.withInt(p.id),
            Variable.withInt(LogicalClock.nextMs()),
          ],
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> getHabitualSettings(int repartoId) async {
    final rows = await customSelect(
      'SELECT h.producto_id, h.enabled, p.nombre AS product_name '
      'FROM habitual_product_settings h '
      'JOIN productos p ON p.id = h.producto_id '
      'WHERE h.reparto_id = ? AND p.deleted = 0 '
      'ORDER BY p.nombre',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return rows
        .map(
          (r) => {
            'producto_id': r.read<int>('producto_id'),
            'enabled': r.read<int>('enabled') == 1,
            'product_name': r.read<String>('product_name'),
          },
        )
        .toList();
  }

  Future<Set<int>> getEnabledHabitualProductIds(int repartoId) async {
    final rows = await customSelect(
      'SELECT h.producto_id '
      'FROM habitual_product_settings h '
      'JOIN productos p ON p.id = h.producto_id '
      'WHERE h.reparto_id = ? AND h.enabled = 1 AND p.deleted = 0',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return rows.map((r) => r.read<int>('producto_id')).toSet();
  }

  Future<void> setHabitualEnabled(
    int repartoId,
    int productoId,
    bool enabled,
  ) async {
    await customUpdate(
      'UPDATE habitual_product_settings SET enabled = ?, dirty = 1, '
      'updated_at = ? WHERE reparto_id = ? AND producto_id = ?',
      variables: [
        Variable.withInt(enabled ? 1 : 0),
        Variable.withInt(LogicalClock.nextMs()),
        Variable.withInt(repartoId),
        Variable.withInt(productoId),
      ],
      updates: {},
    );
    onDataChanged?.call();
  }

  // Returns every habitual_product_settings row as a raw map for cloud sync.
  Future<List<Map<String, dynamic>>> getAllHabitualSettingsAll() async {
    final rows = await customSelect(
      'SELECT id, reparto_id, producto_id, enabled FROM habitual_product_settings',
    ).get();
    return rows
        .map(
          (r) => {
            'id': r.read<int>('id'),
            'reparto_id': r.readNullable<int>('reparto_id'),
            'producto_id': r.read<int>('producto_id'),
            'enabled': r.read<int>('enabled'),
          },
        )
        .toList();
  }

  /// Get total entregado for a product across all clients for a given day.
  Future<int> getTotalEntregadoForProduct(
    int repartoId,
    int productoId,
    String semana,
    int diaSemana,
  ) async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(entregado), 0) AS total FROM entregas '
      'WHERE reparto_id = ? AND producto_id = ? AND semana = ? AND dia_semana = ?',
      variables: [
        Variable.withInt(repartoId),
        Variable.withInt(productoId),
        Variable.withString(semana),
        Variable.withInt(diaSemana),
      ],
    ).getSingle();
    return result.read<int>('total');
  }

  /// Check if a stock_low notification already exists for a product today.
  Future<bool> hasStockLowNotifToday(int productoId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final results = await customSelect(
      "SELECT id FROM app_notifications WHERE type = 'stock_low' AND cliente_id = ? AND created_at LIKE ?",
      variables: [Variable.withInt(productoId), Variable.withString('$today%')],
    ).get();
    return results.isNotEmpty;
  }

  // --- Facturas ---

  Future<int> createFactura({
    required int clienteId,
    required int repartoId,
    required int cbteTipo,
    required int ptoVta,
    required int cbteNro,
    required String fecha,
    required double importeTotal,
    required String cae,
    required String caeFchVto,
    required String itemsJson,
    required String receptorNombre,
    required int receptorDocTipo,
    required String receptorDocNro,
    required String pdfPath,
  }) async {
    final id = await into(facturas).insert(
      FacturasCompanion.insert(
        clienteId: clienteId,
        repartoId: repartoId,
        cbteTipo: Value(cbteTipo),
        ptoVta: ptoVta,
        cbteNro: cbteNro,
        fecha: fecha,
        importeTotal: importeTotal,
        cae: cae,
        caeFchVto: caeFchVto,
        itemsJson: Value(itemsJson),
        receptorNombre: Value(receptorNombre),
        receptorDocTipo: Value(receptorDocTipo),
        receptorDocNro: Value(receptorDocNro),
        pdfPath: Value(pdfPath),
        createdAt: Value(DateTime.now().toIso8601String()),
      ),
    );
    await stampRowDirty('facturas', id);
    onDataChanged?.call();
    return id;
  }

  Future<List<Factura>> getFacturasForClient(int clienteId) {
    return (select(facturas)
          ..where((t) => t.clienteId.equals(clienteId))
          ..orderBy([(t) => OrderingTerm.desc(t.cbteNro)]))
        .get();
  }

  Future<List<Factura>> getAllFacturas() {
    return (select(
      facturas,
    )..orderBy([(t) => OrderingTerm.desc(t.cbteNro)])).get();
  }

  Future<Factura?> getFactura(int id) async {
    final results =
        await (select(facturas)
              ..where((t) => t.id.equals(id))
              ..limit(1))
            .get();
    return results.isEmpty ? null : results.first;
  }

  Future<void> updateFacturaPdfPath(int facturaId, String pdfPath) async {
    await (update(facturas)..where((t) => t.id.equals(facturaId))).write(
      FacturasCompanion(pdfPath: Value(pdfPath)),
    );
    await stampRowDirty('facturas', facturaId);
    onDataChanged?.call();
  }

  // --- Mercado Pago ---
  //
  // P0-4b (audit #4 part 2): the token itself lives in the platform
  // Keystore — see services/secure_credentials.dart. The SQLite column is
  // kept permanently '' on-device (cloud transport schema only). These
  // helpers are the DB half the service orchestrates; nothing else may
  // read or write the column.

  /// Migration read: the pre-4b on-disk copy (if any). Only
  /// SecureCredentials.migrateFromDatabase calls this.
  Future<String> readMpTokenColumn() async {
    final settings = await getSettings();
    return settings.mpAccessToken;
  }

  /// Blank the column without touching dirty counters — used by the
  /// startup migration (the value didn't change; cloud still carries it).
  Future<void> blankMpTokenColumn() async {
    await customStatement(
      "UPDATE user_settings SET mp_access_token = '' WHERE id = 1",
    );
  }

  /// User-edit path (via SecureCredentials.setMpToken): keep the column
  /// empty and bump the MP dirty counters so the push carries the new
  /// keystore value cross-device.
  Future<void> markMpTokenDirtyAndBlankColumn() async {
    await customStatement(
      "UPDATE user_settings SET mp_access_token = '' WHERE id = 1",
    );
    await _markUserSettingsMpDirty();
    onDataChanged?.call();
  }

  // --- AFIP Settings ---

  Future<void> updateAfipSettings({
    String? token,
    String? cuit,
    int? ptoVta,
    String? razonSocial,
    String? domicilio,
    String? condicionIva,
    bool? production,
  }) async {
    final comp = UserSettingsCompanion(
      afipToken: token != null ? Value(token) : const Value.absent(),
      afipCuit: cuit != null ? Value(cuit) : const Value.absent(),
      afipPtoVta: ptoVta != null ? Value(ptoVta) : const Value.absent(),
      afipRazonSocial: razonSocial != null
          ? Value(razonSocial)
          : const Value.absent(),
      afipDomicilio: domicilio != null
          ? Value(domicilio)
          : const Value.absent(),
      afipCondicionIva: condicionIva != null
          ? Value(condicionIva)
          : const Value.absent(),
      afipProduction: production != null
          ? Value(production)
          : const Value.absent(),
    );
    await (update(userSettings)..where((t) => t.id.equals(1))).write(comp);
    await _markUserSettingsAfipDirty();
    onDataChanged?.call();
  }

  // --- cuentas_local (P0.6: profile data in Drift, not cloud-direct) ---

  /// Read this user's profile from local Drift. Returns null if no row.
  Future<Map<String, Object?>?> getCuentaLocal(String userId) async {
    final rows = await customSelect(
      'SELECT email, nombre, telefono, foto_path, foto_url, foto_dirty, foto_upload_pending_path, updated_at, dirty '
      'FROM cuentas_local WHERE user_id = ? LIMIT 1',
      variables: [Variable.withString(userId)],
    ).get();
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      'email': r.read<String>('email'),
      'nombre': r.read<String>('nombre'),
      'telefono': r.read<String>('telefono'),
      'foto_path': r.read<String>('foto_path'),
      'foto_url': r.read<String>('foto_url'),
      'foto_dirty': r.read<int>('foto_dirty'),
      'foto_upload_pending_path': r.read<String>('foto_upload_pending_path'),
      'updated_at': r.read<int>('updated_at'),
      'dirty': r.read<int>('dirty'),
    };
  }

  /// Update just the local file path for the cached profile photo. The path is
  /// per-device and never travels to cloud. When [pendingUpload] is true, the
  /// path is also retained as the source file for SyncService's retry upload.
  Future<void> setCuentaFotoPath({
    required String userId,
    required String fotoPath,
    bool pendingUpload = false,
  }) async {
    final nowMs = LogicalClock.nextMs();
    await customStatement(
      'INSERT INTO cuentas_local ('
      'user_id, email, nombre, telefono, foto_path, foto_url, '
      'foto_dirty, foto_upload_pending_path, updated_at, dirty'
      ") VALUES (?, '', '', '', ?, '', ?, ?, ?, ?) "
      'ON CONFLICT(user_id) DO UPDATE SET '
      'foto_path = excluded.foto_path, '
      'foto_dirty = CASE WHEN excluded.foto_dirty = 1 THEN 1 ELSE foto_dirty END, '
      'foto_upload_pending_path = CASE '
      "WHEN excluded.foto_upload_pending_path <> '' "
      'THEN excluded.foto_upload_pending_path '
      'ELSE foto_upload_pending_path END, '
      'updated_at = excluded.updated_at, '
      'dirty = CASE WHEN excluded.dirty = 1 THEN 1 ELSE dirty END',
      [
        userId,
        fotoPath,
        pendingUpload ? 1 : 0,
        pendingUpload ? fotoPath : '',
        nowMs,
        pendingUpload ? 1 : 0,
      ],
    );
    if (pendingUpload) {
      onDataChanged?.call();
    } else {
      onLocalDataChanged?.call();
    }
  }

  /// Update the synced cloud URL for the profile photo and mark dirty so
  /// SyncService pushes the URL to `cuentas.foto_url` on the next sync.
  Future<void> setCuentaFotoUrl({
    required String userId,
    required String fotoUrl,
  }) async {
    final nowMs = LogicalClock.nextMs();
    await customStatement(
      'INSERT INTO cuentas_local ('
      'user_id, email, nombre, telefono, foto_path, foto_url, '
      'foto_dirty, foto_upload_pending_path, updated_at, dirty'
      ") VALUES (?, '', '', '', '', ?, 1, '', ?, 1) "
      'ON CONFLICT(user_id) DO UPDATE SET '
      'foto_url = excluded.foto_url, '
      'foto_dirty = 1, '
      "foto_upload_pending_path = '', "
      'updated_at = excluded.updated_at, '
      'dirty = 1',
      [userId, fotoUrl, nowMs],
    );
    onDataChanged?.call();
  }

  /// Write this user's profile from a user-initiated edit. Sets dirty=1 so
  /// SyncService picks it up. Refuses to blank a non-blank field unless the
  /// caller has loaded it first — this is the architectural fix for the
  /// blank-overwrite bug. Pass `existingFieldsBeforeEdit` only if you've
  /// just read the row and know what was there.
  Future<void> setCuentaLocal({
    required String userId,
    required String email,
    required String nombre,
    required String telefono,
  }) async {
    final nowMs = LogicalClock.nextMs();
    await customStatement(
      'INSERT INTO cuentas_local (user_id, email, nombre, telefono, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, 1) '
      'ON CONFLICT(user_id) DO UPDATE SET '
      'email = excluded.email, '
      'nombre = excluded.nombre, '
      'telefono = excluded.telefono, '
      'updated_at = excluded.updated_at, '
      'dirty = 1',
      [userId, email, nombre, telefono, nowMs],
    );
    onDataChanged?.call();
  }

  /// Restore profile data from cloud (cuentas table). Called by AuthService
  /// at sign-in when local has no row OR when the cloud row is newer than a
  /// non-dirty local row. NEVER overwrites a dirty local row — local wins.
  /// `fotoUrl` is best-effort: omitting it leaves the existing local URL
  /// untouched so an older client that doesn't know about cuentas.foto_url
  /// can't blank it out on us.
  Future<void> restoreCuentaFromCloud({
    required String userId,
    required String email,
    required String nombre,
    required String telefono,
    String? fotoUrl,
  }) async {
    final existing = await getCuentaLocal(userId);
    if (existing != null && (existing['dirty'] as int) == 1) {
      // Local has unsynced changes — preserve them. Cloud restore must
      // not clobber dirty local data.
      return;
    }
    final nowMs = LogicalClock.nextMs();
    final existingFotoUrl = existing?['foto_url'] as String? ?? '';
    final resolvedFotoUrl = fotoUrl ?? existingFotoUrl;
    final shouldClearLocalPhoto = fotoUrl != null && fotoUrl != existingFotoUrl;
    await customStatement(
      'INSERT INTO cuentas_local ('
      'user_id, email, nombre, telefono, foto_path, foto_url, '
      'foto_dirty, foto_upload_pending_path, updated_at, dirty'
      ') VALUES (?, ?, ?, ?, ?, ?, 0, \'\', ?, 0) '
      'ON CONFLICT(user_id) DO UPDATE SET '
      'email = excluded.email, '
      'nombre = excluded.nombre, '
      'telefono = excluded.telefono, '
      'foto_path = excluded.foto_path, '
      'foto_url = excluded.foto_url, '
      'foto_dirty = 0, '
      "foto_upload_pending_path = '', "
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [
        userId,
        email,
        nombre,
        telefono,
        shouldClearLocalPhoto ? '' : (existing?['foto_path'] as String? ?? ''),
        resolvedFotoUrl,
        nowMs,
      ],
    );
    onLocalDataChanged?.call();
  }

  /// Persist the Storage URL produced by a sync-time retry without marking
  /// the cuenta dirty again. The following cloud upsert will include this URL,
  /// then [markCuentaClean] clears the remaining photo sync flags.
  Future<void> markCuentaFotoUploadComplete({
    required String userId,
    required String fotoUrl,
  }) async {
    final nowMs = LogicalClock.nextMs();
    await customStatement(
      "UPDATE cuentas_local SET foto_url = ?, foto_upload_pending_path = '', updated_at = ? WHERE user_id = ?",
      [fotoUrl, nowMs, userId],
    );
    onLocalDataChanged?.call();
  }

  /// Clear the dirty flag after a successful cloud push.
  Future<void> markCuentaClean(String userId) async {
    await customStatement(
      "UPDATE cuentas_local SET dirty = 0, foto_dirty = 0, foto_upload_pending_path = '' WHERE user_id = ?",
      [userId],
    );
  }

  /// Returns all cuentas_local rows with dirty=1. Used by SyncService push.
  Future<List<Map<String, Object?>>> getDirtyCuentas() async {
    final rows = await customSelect(
      'SELECT user_id, email, nombre, telefono, foto_path, foto_url, '
      'foto_dirty, foto_upload_pending_path, updated_at '
      'FROM cuentas_local WHERE dirty = 1',
    ).get();
    return rows
        .map(
          (r) => {
            'user_id': r.read<String>('user_id'),
            'email': r.read<String>('email'),
            'nombre': r.read<String>('nombre'),
            'telefono': r.read<String>('telefono'),
            'foto_path': r.read<String>('foto_path'),
            'foto_url': r.read<String>('foto_url'),
            'foto_dirty': r.read<int>('foto_dirty'),
            'foto_upload_pending_path': r.read<String>(
              'foto_upload_pending_path',
            ),
            'updated_at': r.read<int>('updated_at'),
          },
        )
        .toList();
  }

  // --- Cloud-restore helpers (P0.3 + P0.5) ---
  //
  // Replace `INSERT OR REPLACE` (which deleted local rows on natural-key
  // conflict, breaking FKs and dropping unsynced edits) with natural-key
  // UPSERT that only updates DATA columns. Local id stays put.
  //
  // P0.5: skip the upsert entirely when local has dirty=1 AND local's
  // updated_at is >= cloud's. That row has unsynced local changes;
  // restoring cloud over it would silently lose user work.

  int _isoToMs(dynamic isoOrInt) {
    if (isoOrInt is int) return isoOrInt;
    if (isoOrInt is String) {
      return DateTime.tryParse(isoOrInt)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  // ─── v52 dirty-row push helpers ─────────────────────────────────
  //
  // `sync_service._pushToCloud` reads only `dirty=1` rows now, sends the
  // local `updated_at` (the moment of the actual edit), then clears
  // `dirty=0` on the specific row IDs after a confirmed-successful
  // upsert. This pair of helpers (one read, one clear) is duplicated
  // per table because each table has a distinct schema; the push site
  // builds upsert payloads directly from the returned maps.
  //
  // Returning raw `Map<String, dynamic>` rather than typed Drift
  // entities because `dirty` and `updated_at` were added via raw SQL
  // and aren't on the Drift Table class.

  Future<List<Map<String, dynamic>>> getDirtyClienteRowsForReparto(
    int repartoId,
  ) async {
    final rows = await customSelect(
      'SELECT * FROM clientes WHERE reparto_id = ? AND dirty = 1',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  Future<List<Map<String, dynamic>>> getDirtyClienteProductoRowsForReparto(
    int repartoId,
  ) async {
    // Joined against clientes so the sync push loop (which iterates by
    // reparto) can pick up a dirty cliente_productos row even when its
    // parent cliente wasn't itself dirty.
    final rows = await customSelect(
      'SELECT cp.* FROM cliente_productos cp '
      'INNER JOIN clientes c ON c.id = cp.cliente_id '
      'WHERE c.reparto_id = ? AND cp.dirty = 1',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  Future<List<Map<String, dynamic>>> getDirtyEntregaRowsForReparto(
    int repartoId,
  ) async {
    final rows = await customSelect(
      'SELECT * FROM entregas WHERE reparto_id = ? AND dirty = 1',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  Future<List<Map<String, dynamic>>> getDirtyPagoRowsForReparto(
    int repartoId,
  ) async {
    final rows = await customSelect(
      'SELECT * FROM pagos WHERE reparto_id = ? AND dirty = 1',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  Future<List<Map<String, dynamic>>> getDirtyCargaRowsForReparto(
    int repartoId,
  ) async {
    final rows = await customSelect(
      'SELECT * FROM carga_diaria WHERE reparto_id = ? AND dirty = 1',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  Future<List<Map<String, dynamic>>> getDirtyResumenRowsForReparto(
    int repartoId,
  ) async {
    final rows = await customSelect(
      'SELECT * FROM resumenes WHERE reparto_id = ? AND dirty = 1',
      variables: [Variable.withInt(repartoId)],
    ).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  // --- Phase 2 remainder / v55: dirty helpers for the 7 full-upload tables ---
  //
  // Each table now has `dirty INTEGER NOT NULL DEFAULT 0` +
  // `updated_at INTEGER NOT NULL DEFAULT 0`. Every mutator stamps the row
  // dirty=1 with a hybrid-clock millisecond timestamp (LogicalClock.nextMs).
  // The push code in sync_service.dart fetches only dirty rows, sends the
  // local updated_at to cloud (so reject_stale_update can arbitrate
  // honestly), and clears dirty=0 on successful upsert.

  /// Stamp a single row dirty=1 with the current logical-clock timestamp.
  /// Mirrors the per-table `_stampClienteDirty` / `_stampResumenDirty`
  /// helpers but generic because the 7 tables have heterogeneous shapes.
  Future<void> stampRowDirty(String table, int id) async {
    await customStatement(
      'UPDATE $table SET dirty = 1, updated_at = ? WHERE id = ?',
      [LogicalClock.nextMs(), id],
    );
  }

  /// Stamp a habitual_product_settings row dirty via its composite NK.
  /// Used by `setHabitualEnabled` and `ensureHabitualSettingsExist`
  /// because those call sites don't have the row's id, only (reparto_id,
  /// producto_id). Tolerates the row not existing yet (UPDATE does
  /// nothing) — the caller's INSERT path stamps via stampRowDirty
  /// instead.
  Future<void> stampHabitualDirty(int repartoId, int productoId) async {
    await customStatement(
      'UPDATE habitual_product_settings SET dirty = 1, updated_at = ? '
      'WHERE reparto_id = ? AND producto_id = ?',
      [LogicalClock.nextMs(), repartoId, productoId],
    );
  }

  /// Stamp a stock_notif_settings row dirty via its NK (producto_id is
  /// unique per device since the table is local-only — there is no
  /// reparto_id collision in the current schema).
  Future<void> stampStockNotifDirty(int productoId) async {
    await customStatement(
      'UPDATE stock_notif_settings SET dirty = 1, updated_at = ? '
      'WHERE producto_id = ?',
      [LogicalClock.nextMs(), productoId],
    );
  }

  /// Fetch every dirty row from [table] as a raw map. The push code
  /// projects the columns it needs into the cloud payload, so we return
  /// untyped rows rather than table-specific models.
  Future<List<Map<String, dynamic>>> getDirtyRowsForTable(String table) async {
    final rows = await customSelect(
      'SELECT * FROM $table WHERE dirty = 1',
    ).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
  }

  /// F7: chunked dirty bulk-flip. SQLite's host-variable cap is 999 by
  /// default (32766 in newer builds), so a single `IN (?, ?, …, ?)` blows
  /// up on big backlogs. Always split at 500.
  Future<void> _setDirtyByIds(
    String table,
    List<int> ids, {
    required int dirty,
  }) async {
    if (ids.isEmpty) return;
    for (var i = 0; i < ids.length; i += 500) {
      final end = (i + 500).clamp(0, ids.length);
      final batch = ids.sublist(i, end);
      final placeholders = List.filled(batch.length, '?').join(',');
      await customStatement(
        'UPDATE $table SET dirty = $dirty WHERE id IN ($placeholders)',
        batch,
      );
    }
  }

  /// F6: re-stamp dirty=1 by id. Used when post-push confirmation fails
  /// after dirty was already cleared, so the next cycle retries.
  /// Doesn't touch `updated_at` — the local timestamp is still correct;
  /// we just need the row reconsidered for push.
  Future<void> markDirtyByIds(String table, List<int> ids) =>
      _setDirtyByIds(table, ids, dirty: 1);

  /// P0-1 (audit #1): guarded dirty-clear engine. Clears dirty=0 ONLY when
  /// the row's `updated_at` still equals the value captured in the push
  /// snapshot. A row edited while the upsert was in flight no longer
  /// matches (every mutator stamps a fresh LogicalClock ms), so it keeps
  /// dirty=1 and re-pushes next cycle — pushes are idempotent upserts, so
  /// the retry is harmless. The old unconditional `WHERE id IN (...)` form
  /// silently abandoned mid-flight edits AND let the post-push confirmation
  /// restore the older cloud copy over them (dirty=0 disables the
  /// `_localIsDirtyAndNewer` pull guard) — full local data loss.
  Future<void> _clearDirtyGuarded(
    String table,
    List<Map<String, Object?>> snapshotRows,
  ) async {
    if (snapshotRows.isEmpty) return;
    await transaction(() async {
      for (final row in snapshotRows) {
        await customStatement(
          'UPDATE $table SET dirty = 0 WHERE id = ? AND updated_at = ?',
          [row['id'], row['updated_at']],
        );
      }
    });
  }

  /// Phase 2 remainder: generic "clear dirty for these pushed rows in
  /// [table]". Used by the dirty-aware push blocks for repartos /
  /// producto_precios / stock_notif_settings / habitual_product_settings /
  /// facturas. Takes the push-snapshot rows (id + updated_at), NOT bare
  /// ids — see [_clearDirtyGuarded] for why.
  Future<void> clearDirtyForTable(
    String table,
    List<Map<String, Object?>> snapshotRows,
  ) => _clearDirtyGuarded(table, snapshotRows);

  /// Guarded clear for clientes. Preserves dirty_fields until post-push
  /// confirmation restores the cloud row — if confirmation fails,
  /// markDirtyByIds can retry with the same field mask instead of
  /// degrading to a whole-row legacy push. Rows edited mid-push keep
  /// dirty=1 AND their dirty_fields mask, so the next cycle re-merges.
  Future<void> clearClientesDirty(List<Map<String, Object?>> snapshotRows) =>
      _clearDirtyGuarded('clientes', snapshotRows);

  Future<void> clearClienteProductosDirty(
    List<Map<String, Object?>> snapshotRows,
  ) => _clearDirtyGuarded('cliente_productos', snapshotRows);
  Future<void> clearEntregasDirty(List<Map<String, Object?>> snapshotRows) =>
      _clearDirtyGuarded('entregas', snapshotRows);
  Future<void> clearPagosDirty(List<Map<String, Object?>> snapshotRows) =>
      _clearDirtyGuarded('pagos', snapshotRows);

  /// Guarded clear for carga_diaria. Beyond the dirty flag, the carga push
  /// is delta-based (CAS increment of `cantidad - cantidad_synced`), so the
  /// clear must advance `cantidad_synced` by the delta that was ACTUALLY
  /// pushed (snapshot cantidad − snapshot cantidad_synced) rather than
  /// jumping it to the current cantidad:
  ///   • matched row (no mid-flight edit): synced += appliedDelta lands on
  ///     the current cantidad — identical to the old `synced = cantidad`.
  ///   • mid-flight edit: dirty stays 1 and synced only advances past the
  ///     pushed delta, so the next cycle pushes exactly the residual edit.
  ///     The old form jumped synced past the edit — the delta was lost.
  /// `pending_push_id` clears in both cases: this push COMPLETED, so a
  /// residual delta must mint a fresh push id (reusing the old one would
  /// be deduped by cas_carga_push_log and silently dropped).
  Future<void> clearCargaDirty(List<Map<String, Object?>> snapshotRows) async {
    if (snapshotRows.isEmpty) return;
    await transaction(() async {
      for (final row in snapshotRows) {
        final snapCantidad = ((row['cantidad'] ?? 0) as num).toInt();
        final snapSynced = ((row['cantidad_synced'] ?? 0) as num).toInt();
        final appliedDelta = snapCantidad - snapSynced;
        await customStatement(
          'UPDATE carga_diaria SET '
          'cantidad_synced = cantidad_synced + ?, '
          'pending_push_id = NULL, '
          'dirty = CASE WHEN updated_at = ? THEN 0 ELSE dirty END '
          'WHERE id = ?',
          [appliedDelta, row['updated_at'], row['id']],
        );
      }
    });
  }

  Future<void> setCargaPendingPushId(int id, String pushId) async {
    await customStatement(
      'UPDATE carga_diaria SET pending_push_id = ? WHERE id = ?',
      [pushId, id],
    );
  }

  Future<void> clearResumenesDirty(List<Map<String, Object?>> snapshotRows) =>
      _clearDirtyGuarded('resumenes', snapshotRows);

  /// Sum of dirty-row counts across every cloud-synced business table.
  /// `sync_service._hasLocalChanges` ORs this with `user_settings`'s
  /// existing dirty token so the periodic sync runs whenever there's
  /// anything unpushed.
  /// Total dirty-row count across every table that participates in the
  /// dirty-aware push contract. Used by `SyncService.syncAll` to decide
  /// whether `_hasLocalChanges` should be retained for the next cycle.
  ///
  /// Phase 10a: extended from the 6 v52 tables to also cover the 6 v55
  /// dirty-aware tables AND the cuentas_local profile table. Without this
  /// extension, a phone with only v55-dirty rows (e.g. a freshly-edited
  /// producto) would have `_hasLocalChanges` clear after the first push
  /// cycle, then the periodic 2-min push skip-check would suppress
  /// retries — leaving the dirty row stranded locally if the push
  /// silently lost its uid stamp or got reordered.
  ///
  /// etiqueta_colors is intentionally NOT included — per Phase 10d it's
  /// a local-only per-device table; its dirty stamping was removed.
  /// stock_notif_settings IS included because Phase 10c wired it into
  /// the pull path, so it's now a true cross-device sync table.
  /// pending_deletions IS included because queued tombstones must keep retrying
  /// until the cloud DELETE lands; without this, a failed delete clears
  /// _hasLocalChanges and the periodic sync skips retrying forever.
  ///
  /// v85 final audit: user_settings' legacy `settings_dirty` counter IS
  /// included — it covers every per-section settings edit (AFIP/MP/prefs
  /// AND the recorrido + instances registry). Without it, sign-out after
  /// a failed force-push wiped unpushed recorrido marks / vista edits
  /// with the guard reading "0 cambios".
  Future<int> totalDirtyRowCount() async {
    final r = await customSelect(
      'SELECT '
      '(SELECT COUNT(*) FROM clientes WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM cliente_productos WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM entregas WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM pagos WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM carga_diaria WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM resumenes WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM productos WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM repartos WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM producto_precios WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM stock_notif_settings WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM habitual_product_settings WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM facturas WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM cuentas_local WHERE dirty = 1) '
      '+ (SELECT COUNT(*) FROM pending_deletions) '
      "+ COALESCE((SELECT settings_dirty FROM user_settings WHERE id = 1), 0) "
      'AS total',
    ).getSingle();
    return r.read<int>('total');
  }

  /// True if local has a dirty row newer than cloud. Caller should skip
  /// the upsert in that case to preserve local edits.
  Future<bool> _localIsDirtyAndNewer({
    required String selectSql,
    required List<Variable> selectArgs,
    required dynamic cloudUpdatedAt,
  }) async {
    final rows = await customSelect(selectSql, variables: selectArgs).get();
    if (rows.isEmpty) return false;
    final localDirty = rows.first.read<int>('dirty');
    if (localDirty != 1) return false;
    final localMs = rows.first.read<int>('updated_at');
    final cloudMs = _isoToMs(cloudUpdatedAt);
    return localMs >= cloudMs;
  }

  /// Restore one carga_diaria row from cloud. Natural-key UPSERT, dirty-aware.
  Future<void> restoreCargaFromCloud(Map<String, dynamic> c) async {
    final cloudUpdatedAt = c['updated_at'];
    final cloudCantidad = ((c['cantidad'] ?? 0) as num).toInt();
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql:
          'SELECT updated_at, dirty FROM carga_diaria WHERE reparto_id = ? AND producto_id = ? AND dia_semana = ? AND semana = ? LIMIT 1',
      selectArgs: [
        Variable.withInt(c['reparto_id'] as int),
        Variable.withInt(c['producto_id'] as int),
        Variable.withInt(c['dia_semana'] as int),
        Variable.withString(c['semana'] as String),
      ],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) {
      await customStatement(
        'UPDATE carga_diaria SET cantidad_synced = ? '
        'WHERE reparto_id = ? AND producto_id = ? AND dia_semana = ? AND semana = ?',
        [
          cloudCantidad,
          c['reparto_id'],
          c['producto_id'],
          c['dia_semana'],
          c['semana'],
        ],
      );
      return;
    }
    final cloudMs = _isoToMs(cloudUpdatedAt);
    final fecha = (c['fecha'] as String?)?.isNotEmpty == true
        ? c['fecha'] as String
        : fechaFromDisplayedSemana(
            c['semana'] as String,
            c['dia_semana'] as int,
          );
    await customStatement(
      'INSERT INTO carga_diaria (id, producto_id, reparto_id, dia_semana, semana, cantidad, cantidad_synced, remanente, fecha, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(reparto_id, producto_id, dia_semana, semana) DO UPDATE SET '
      'cantidad = excluded.cantidad, '
      'cantidad_synced = excluded.cantidad_synced, '
      'remanente = excluded.remanente, '
      'fecha = excluded.fecha, '
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [
        c['id'],
        c['producto_id'],
        c['reparto_id'],
        c['dia_semana'],
        c['semana'],
        cloudCantidad,
        cloudCantidad,
        c['remanente'] ?? 0,
        fecha,
        cloudMs,
      ],
    );
  }

  /// Restore one entregas row from cloud. Natural-key UPSERT, dirty-aware.
  /// Snapshot price preservation rule: cloud non-zero wins on restore.
  Future<void> restoreEntregaFromCloud(Map<String, dynamic> e) async {
    final cloudUpdatedAt = e['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql:
          'SELECT updated_at, dirty FROM entregas WHERE cliente_id = ? AND reparto_id = ? AND producto_id = ? AND semana = ? AND dia_semana = ? LIMIT 1',
      selectArgs: [
        Variable.withInt(e['cliente_id'] as int),
        Variable.withInt(e['reparto_id'] as int),
        Variable.withInt(e['producto_id'] as int),
        Variable.withString(e['semana'] as String),
        Variable.withInt(e['dia_semana'] as int),
      ],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    final fecha = (e['fecha'] as String?)?.isNotEmpty == true
        ? e['fecha'] as String
        : fechaFromDisplayedSemana(
            e['semana'] as String,
            e['dia_semana'] as int,
          );
    await customStatement(
      'INSERT INTO entregas (id, cliente_id, reparto_id, producto_id, semana, dia_semana, entregado, devuelto, precio_unitario, fecha, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(cliente_id, reparto_id, producto_id, semana, dia_semana) DO UPDATE SET '
      'entregado = excluded.entregado, '
      'devuelto = excluded.devuelto, '
      'precio_unitario = CASE '
      '  WHEN excluded.precio_unitario > 0 THEN excluded.precio_unitario '
      '  ELSE entregas.precio_unitario '
      'END, '
      'fecha = excluded.fecha, '
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [
        e['id'],
        e['cliente_id'],
        e['reparto_id'],
        e['producto_id'],
        e['semana'],
        e['dia_semana'],
        e['entregado'] ?? 0,
        e['devuelto'] ?? 0,
        e['precio_unitario'] ?? 0.0,
        fecha,
        cloudMs,
      ],
    );
  }

  /// Restore one pagos row from cloud. Natural-key UPSERT, dirty-aware.
  Future<void> restorePagoFromCloud(Map<String, dynamic> p) async {
    final cloudUpdatedAt = p['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql:
          'SELECT updated_at, dirty FROM pagos WHERE cliente_id = ? AND reparto_id = ? AND semana = ? AND dia_semana = ? LIMIT 1',
      selectArgs: [
        Variable.withInt(p['cliente_id'] as int),
        Variable.withInt(p['reparto_id'] as int),
        Variable.withString(p['semana'] as String),
        Variable.withInt(p['dia_semana'] as int),
      ],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    final fecha = (p['fecha'] as String?)?.isNotEmpty == true
        ? p['fecha'] as String
        : fechaFromDisplayedSemana(
            p['semana'] as String,
            p['dia_semana'] as int,
          );
    await customStatement(
      'INSERT INTO pagos (id, cliente_id, reparto_id, semana, dia_semana, metodo_pago, monto, fecha, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(cliente_id, reparto_id, semana, dia_semana) DO UPDATE SET '
      'metodo_pago = excluded.metodo_pago, '
      'monto = excluded.monto, '
      'fecha = excluded.fecha, '
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [
        p['id'],
        p['cliente_id'],
        p['reparto_id'],
        p['semana'],
        p['dia_semana'],
        p['metodo_pago'],
        p['monto'] ?? 0.0,
        fecha,
        cloudMs,
      ],
    );
  }

  static const Set<String> _clienteSyncedFields = {
    'reparto_id',
    'dia_semana',
    'nombre',
    'direccion',
    'telefono',
    'frecuencia',
    'etiqueta',
    'notas',
    'orden',
    'cuenta_corriente',
    'show_on_map',
    'doc_tipo',
    'doc_nro',
    'marked_semana',
    'lat',
    'lng',
    'geocoded_direccion',
  };

  static Object? _normalizeClienteValue(String field, Object? value) {
    if (field == 'show_on_map') {
      return value == true || value == 1 ? 1 : 0;
    }
    if (value is num &&
        (field == 'cuenta_corriente' || field == 'lat' || field == 'lng')) {
      return value.toDouble();
    }
    return value;
  }

  static Object? _clienteValue(Map<String, dynamic> row, String field) {
    if (field == 'show_on_map') {
      return row[field] == true || row[field] == 1 ? 1 : 0;
    }
    return row[field];
  }

  static bool _clienteFieldEqual(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
    String field,
  ) {
    return _normalizeClienteValue(field, _clienteValue(local, field)) ==
        _normalizeClienteValue(field, _clienteValue(cloud, field));
  }

  Future<void> _archiveClienteConflict({
    required int clienteId,
    required String reason,
    required Map<String, dynamic> local,
    required Map<String, dynamic> cloud,
  }) async {
    await customStatement(
      'INSERT INTO clientes_sync_conflicts '
      '(cliente_id, detected_at, reason, local_json, cloud_json) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        clienteId,
        LogicalClock.nextMs(),
        reason,
        jsonEncode(local),
        jsonEncode(cloud),
      ],
    );
  }

  /// Restore one clientes row from cloud (v52). UPSERT by `id`, dirty-aware.
  /// Preserves local `lat / lng / geocoded_direccion` when cloud has no
  /// coordinates — mirrors the conflict resolution at
  /// sync_service.dart:1992 so we don't lose the local geocode cache.
  ///
  /// A DIRTY local row always takes the field-masked merge: its dirty
  /// fields stay local (and stay dirty for the next push), everything else
  /// comes from cloud. The old `local.updated_at >= cloud.updated_at`
  /// pre-condition made the winner of a conflict depend on wall-clock skew:
  /// a phone whose clock ran behind would have its unpushed reorder
  /// silently overwritten — and its dirty flag CLEARED — by any later web
  /// edit of an unrelated field. Field-level merge replaces that roulette
  /// with a deterministic rule (local dirty fields win until pushed).
  Future<void> restoreClienteFromCloud(Map<String, dynamic> c) async {
    final cloudUpdatedAt = c['updated_at'];
    final localRows = await customSelect(
      'SELECT * FROM clientes WHERE id = ? LIMIT 1',
      variables: [Variable.withInt(c['id'] as int)],
    ).get();
    if (localRows.isNotEmpty) {
      final local = Map<String, dynamic>.from(localRows.first.data);
      final localDirty = (local['dirty'] as int? ?? 0) == 1;
      if (localDirty) {
        final rawDirtyFields = local['dirty_fields'] as String? ?? '';
        var dirtyFields = _decodeDirtyFields(
          rawDirtyFields,
        ).intersection(_clienteSyncedFields);

        // Rows dirtied before v59 have no field mask. Treat only `orden` as
        // safe to preserve and archive any profile differences before taking
        // cloud. This stops old row-level dirty stamps from overwriting web
        // edits while keeping a local recovery trail for genuine legacy
        // offline profile edits.
        if (dirtyFields.isEmpty) {
          final legacyProfileDiffs = _clienteSyncedFields
              .where((f) => f != 'orden' && !_clienteFieldEqual(local, c, f))
              .toList();
          if (legacyProfileDiffs.isNotEmpty) {
            await _archiveClienteConflict(
              clienteId: c['id'] as int,
              reason: 'legacy_dirty_profile_conflict',
              local: local,
              cloud: c,
            );
          }
          dirtyFields = _clienteFieldEqual(local, c, 'orden')
              ? <String>{}
              : {'orden'};
        } else {
          dirtyFields = dirtyFields
              .where((field) => !_clienteFieldEqual(local, c, field))
              .toSet();
        }

        final cloudMs = _isoToMs(cloudUpdatedAt);
        final preserve = dirtyFields;
        final assignments = <String>[];
        final args = <Object?>[];
        void applyField(String column, Object? value) {
          if (preserve.contains(column)) return;
          assignments.add('$column = ?');
          args.add(_normalizeClienteValue(column, value));
        }

        applyField('reparto_id', c['reparto_id']);
        applyField('dia_semana', c['dia_semana']);
        applyField('nombre', c['nombre'] ?? '');
        applyField('direccion', c['direccion'] ?? '');
        applyField('telefono', c['telefono'] ?? '');
        applyField('frecuencia', c['frecuencia'] ?? 'semanal');
        applyField('etiqueta', c['etiqueta'] ?? '');
        applyField('notas', c['notas'] ?? '');
        applyField('orden', c['orden'] ?? 0);
        applyField(
          'cuenta_corriente',
          (c['cuenta_corriente'] as num?)?.toDouble() ?? 0.0,
        );
        applyField('show_on_map', c['show_on_map']);
        applyField('doc_tipo', c['doc_tipo'] ?? 99);
        applyField('doc_nro', c['doc_nro'] ?? '0');
        applyField('marked_semana', c['marked_semana']);
        if (c['lat'] != null && c['lng'] != null) {
          applyField('lat', c['lat']);
          applyField('lng', c['lng']);
          applyField('geocoded_direccion', c['geocoded_direccion']);
        }

        if (preserve.isEmpty) {
          assignments.add('updated_at = ?');
          args.add(cloudMs);
          assignments.add('dirty = 0');
          assignments.add("dirty_fields = ''");
        } else {
          assignments.add('dirty_fields = ?');
          args.add(_encodeDirtyFields(preserve));
        }
        if (assignments.isNotEmpty) {
          args.add(c['id']);
          await customStatement(
            'UPDATE clientes SET ${assignments.join(', ')} WHERE id = ?',
            args,
          );
        }
        return;
      }
    }
    final cloudMs = _isoToMs(cloudUpdatedAt);
    final showOnMap = (c['show_on_map'] == true || c['show_on_map'] == 1)
        ? 1
        : 0;
    await customStatement(
      'INSERT INTO clientes (id, reparto_id, dia_semana, nombre, direccion, telefono, frecuencia, etiqueta, notas, orden, cuenta_corriente, show_on_map, doc_tipo, doc_nro, marked_semana, lat, lng, geocoded_direccion, updated_at, dirty, dirty_fields) '
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, '') "
      'ON CONFLICT(id) DO UPDATE SET '
      'reparto_id = excluded.reparto_id, '
      'dia_semana = excluded.dia_semana, '
      'nombre = excluded.nombre, '
      'direccion = excluded.direccion, '
      'telefono = excluded.telefono, '
      'frecuencia = excluded.frecuencia, '
      'etiqueta = excluded.etiqueta, '
      'notas = excluded.notas, '
      'orden = excluded.orden, '
      'cuenta_corriente = excluded.cuenta_corriente, '
      'show_on_map = excluded.show_on_map, '
      'doc_tipo = excluded.doc_tipo, '
      'doc_nro = excluded.doc_nro, '
      'marked_semana = excluded.marked_semana, '
      'lat = COALESCE(excluded.lat, lat), '
      'lng = COALESCE(excluded.lng, lng), '
      'geocoded_direccion = CASE '
      '  WHEN excluded.lat IS NOT NULL AND excluded.lng IS NOT NULL '
      '  THEN excluded.geocoded_direccion '
      '  ELSE geocoded_direccion '
      'END, '
      'updated_at = excluded.updated_at, '
      'dirty = 0, '
      "dirty_fields = ''",
      [
        c['id'],
        c['reparto_id'],
        c['dia_semana'],
        c['nombre'] ?? '',
        c['direccion'] ?? '',
        c['telefono'] ?? '',
        c['frecuencia'] ?? 'semanal',
        c['etiqueta'] ?? '',
        c['notas'] ?? '',
        c['orden'] ?? 0,
        (c['cuenta_corriente'] as num?)?.toDouble() ?? 0.0,
        showOnMap,
        c['doc_tipo'] ?? 99,
        c['doc_nro'] ?? '0',
        c['marked_semana'],
        c['lat'],
        c['lng'],
        c['geocoded_direccion'],
        cloudMs,
      ],
    );
  }

  /// Restore one cliente_productos row from cloud (v52). UPSERT by `id`,
  /// dirty-aware. No natural-key index on this table so conflict resolves
  /// on the autoincrement id.
  Future<void> restoreClienteProductoFromCloud(Map<String, dynamic> cp) async {
    final cloudUpdatedAt = cp['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql:
          'SELECT updated_at, dirty FROM cliente_productos WHERE id = ? LIMIT 1',
      selectArgs: [Variable.withInt(cp['id'] as int)],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    await customStatement(
      'INSERT INTO cliente_productos (id, cliente_id, producto_id, cantidad_habitual, precio_tipo_id, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(id) DO UPDATE SET '
      'cliente_id = excluded.cliente_id, '
      'producto_id = excluded.producto_id, '
      'cantidad_habitual = excluded.cantidad_habitual, '
      'precio_tipo_id = excluded.precio_tipo_id, '
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [
        cp['id'],
        cp['cliente_id'],
        cp['producto_id'],
        cp['cantidad_habitual'] ?? 1,
        cp['precio_tipo_id'],
        cloudMs,
      ],
    );
  }

  /// Restore one resumenes row from cloud (v52). UPSERT by `id`,
  /// dirty-aware. Mirrors the previous raw INSERT OR REPLACE at
  /// sync_service.dart:1668 but respects local dirty state.
  /// P1-8 / v81: NK-keyed (reparto_id, fecha, dia_semana) like
  /// entregas/pagos — cloud's id can differ from mobile's local id when two
  /// devices created the same day's resumen, so both the dirty guard and
  /// the upsert resolve on the natural key. Local id is preserved on
  /// conflict.
  Future<void> restoreResumenFromCloud(Map<String, dynamic> r) async {
    final cloudUpdatedAt = r['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql:
          'SELECT updated_at, dirty FROM resumenes '
          'WHERE reparto_id = ? AND fecha = ? AND dia_semana = ? LIMIT 1',
      selectArgs: [
        Variable.withInt(r['reparto_id'] as int),
        Variable.withString(r['fecha'] as String),
        Variable.withInt(r['dia_semana'] as int),
      ],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    const updateClause =
        'ON CONFLICT(reparto_id, fecha, dia_semana) DO UPDATE SET '
        'semana = excluded.semana, '
        'duracion_segundos = excluded.duracion_segundos, '
        'efectivo = excluded.efectivo, '
        'transferencia = excluded.transferencia, '
        'cuenta_corriente = excluded.cuenta_corriente, '
        'gastos = excluded.gastos, '
        'sueldo_bruto = excluded.sueldo_bruto, '
        'sueldo_neto = excluded.sueldo_neto, '
        'productos_json = excluded.productos_json, '
        'gastos_json = excluded.gastos_json, '
        'sessions_json = excluded.sessions_json, '
        'created_at = excluded.created_at, '
        'updated_at = excluded.updated_at, '
        'dirty = 0';
    final values = <Object?>[
      r['reparto_id'],
      r['fecha'],
      r['semana'],
      r['dia_semana'],
      r['duracion_segundos'] ?? 0,
      (r['efectivo'] as num?)?.toDouble() ?? 0.0,
      (r['transferencia'] as num?)?.toDouble() ?? 0.0,
      (r['cuenta_corriente'] as num?)?.toDouble() ?? 0.0,
      (r['gastos'] as num?)?.toDouble() ?? 0.0,
      (r['sueldo_bruto'] as num?)?.toDouble() ?? 0.0,
      (r['sueldo_neto'] as num?)?.toDouble() ?? 0.0,
      r['productos_json'] ?? '',
      r['gastos_json'] ?? '',
      r.containsKey('sessions_json') ? r['sessions_json'] ?? '[]' : '[]',
      r['created_at'] ?? '',
      cloudMs,
    ];
    try {
      await customStatement(
        'INSERT INTO resumenes (id, reparto_id, fecha, semana, dia_semana, duracion_segundos, efectivo, transferencia, cuenta_corriente, gastos, sueldo_bruto, sueldo_neto, productos_json, gastos_json, sessions_json, created_at, updated_at, dirty) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
        '$updateClause',
        [r['id'], ...values],
      );
    } on Exception {
      // Legacy edge: cloud's id is already taken locally by a DIFFERENT
      // day's resumen (pre-v80 small ids overlapped across devices). The
      // PK violation fires before the NK conflict can resolve — retry
      // letting SQLite assign a fresh local id; NK upsert semantics are
      // identical.
      await customStatement(
        'INSERT INTO resumenes (reparto_id, fecha, semana, dia_semana, duracion_segundos, efectivo, transferencia, cuenta_corriente, gastos, sueldo_bruto, sueldo_neto, productos_json, gastos_json, sessions_json, created_at, updated_at, dirty) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
        '$updateClause',
        values,
      );
    }
  }

  // ─── Phase 10b — dirty-aware pull for v55 tables ─────────────────
  // Each helper mirrors the v52 pattern (restoreClienteFromCloud etc.):
  //   1. Check _localIsDirtyAndNewer — if local has an unpushed edit
  //      stamped newer than the cloud row, SKIP (local wins; next push
  //      flushes the local change).
  //   2. INSERT ... ON CONFLICT(id) DO UPDATE — adopt cloud's values,
  //      stamp local `updated_at` from cloud's ISO timestamp (parsed via
  //      _isoToMs), reset `dirty = 0`.
  //
  // Replaces the raw `INSERT OR REPLACE` patterns in sync_service.dart
  // that clobbered local dirty edits on every pull.

  Future<void> restoreProductoFromCloud(Map<String, dynamic> p) async {
    final cloudUpdatedAt = p['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql: 'SELECT updated_at, dirty FROM productos WHERE id = ? LIMIT 1',
      selectArgs: [Variable.withInt(p['id'] as int)],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    final hasPackSize = p.containsKey('pack_size');
    final hasMayorista = p.containsKey('precio_mayorista');
    await customStatement(
      'INSERT INTO productos (id, reparto_id, nombre, orden, precio, deleted, pack_size, precio_mayorista, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(id) DO UPDATE SET '
      'reparto_id = excluded.reparto_id, '
      'nombre = excluded.nombre, '
      'orden = excluded.orden, '
      // Per-column dirty guard for `precio` mirrors the existing
      // precio_mayorista pattern below: if the local row has a pending
      // precio edit (precio_dirty = 1), keep the local value during a
      // cloud restore. Without this, a cloud pull that arrives before the
      // local push completes would clobber the operator's MAYORISTA save
      // with whatever stale value cloud last had (e.g. a 1111 written by
      // older VENTA-add code) — gastos would then show pack × stale_cloud
      // instead of pack × user_mayorista. This is the bug v1.0.94+106
      // fixes.
      'precio = CASE '
      'WHEN productos.precio_dirty = 1 THEN productos.precio '
      'ELSE excluded.precio END, '
      'deleted = excluded.deleted, '
      // Per-column dirty guard for pack_size (mirrors precio): a pending local
      // pack edit (pack_size_dirty = 1) survives a cloud pull instead of being
      // reverted to a stale cloud value.
      'pack_size = CASE '
      'WHEN productos.pack_size_dirty = 1 THEN productos.pack_size '
      'WHEN ? THEN excluded.pack_size '
      'ELSE productos.pack_size END, '
      'precio_mayorista = CASE '
      'WHEN productos.precio_mayorista_dirty = 1 THEN productos.precio_mayorista '
      'WHEN ? THEN excluded.precio_mayorista '
      'ELSE productos.precio_mayorista END, '
      'updated_at = CASE '
      'WHEN productos.precio_mayorista_dirty = 1 OR productos.precio_dirty = 1 OR productos.pack_size_dirty = 1 THEN productos.updated_at '
      'ELSE excluded.updated_at END, '
      'dirty = CASE '
      'WHEN productos.precio_mayorista_dirty = 1 OR productos.precio_dirty = 1 OR productos.pack_size_dirty = 1 THEN 1 '
      'ELSE 0 END',
      [
        p['id'],
        p['reparto_id'],
        p['nombre'],
        p['orden'] ?? 0,
        (p['precio'] as num?)?.toDouble() ?? 0.0,
        (p['deleted'] ?? false) == true ? 1 : 0,
        (p['pack_size'] as num?)?.toInt(),
        (p['precio_mayorista'] as num?)?.toDouble(),
        cloudMs,
        hasPackSize ? 1 : 0,
        hasMayorista ? 1 : 0,
      ],
    );
  }

  Future<void> restoreRepartoFromCloud(
    Map<String, dynamic> r,
    String userId,
  ) async {
    final cloudUpdatedAt = r['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql: 'SELECT updated_at, dirty FROM repartos WHERE id = ? LIMIT 1',
      selectArgs: [Variable.withInt(r['id'] as int)],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    await customStatement(
      'INSERT INTO repartos (id, nombre, user_id, orden, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(id) DO UPDATE SET '
      'nombre = excluded.nombre, '
      'user_id = excluded.user_id, '
      'orden = excluded.orden, '
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [r['id'], r['nombre'], userId, r['orden'] ?? 0, cloudMs],
    );
  }

  Future<void> restoreProductoPrecioFromCloud(
    Map<String, dynamic> pp, {
    int? fallbackRepartoId,
  }) async {
    final cloudUpdatedAt = pp['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql:
          'SELECT updated_at, dirty FROM producto_precios WHERE id = ? LIMIT 1',
      selectArgs: [Variable.withInt(pp['id'] as int)],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    final repartoId = pp['reparto_id'] ?? fallbackRepartoId;
    await customStatement(
      'INSERT INTO producto_precios (id, reparto_id, producto_id, nombre, precio, orden, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(id) DO UPDATE SET '
      'reparto_id = excluded.reparto_id, '
      'producto_id = excluded.producto_id, '
      'nombre = excluded.nombre, '
      'precio = excluded.precio, '
      'orden = excluded.orden, '
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [
        pp['id'],
        repartoId,
        pp['producto_id'],
        pp['nombre'],
        (pp['precio'] as num?)?.toDouble() ?? 0.0,
        pp['orden'] ?? 0,
        cloudMs,
      ],
    );
  }

  Future<void> restoreStockNotifSettingFromCloud(Map<String, dynamic> s) async {
    final cloudUpdatedAt = s['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql:
          'SELECT updated_at, dirty FROM stock_notif_settings WHERE id = ? LIMIT 1',
      selectArgs: [Variable.withInt(s['id'] as int)],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    final enabledInt = (s['enabled'] is bool)
        ? ((s['enabled'] as bool) ? 1 : 0)
        : (s['enabled'] ?? 1);
    await customStatement(
      'INSERT INTO stock_notif_settings (id, reparto_id, producto_id, enabled, threshold, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(id) DO UPDATE SET '
      'reparto_id = excluded.reparto_id, '
      'producto_id = excluded.producto_id, '
      'enabled = excluded.enabled, '
      'threshold = excluded.threshold, '
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [
        s['id'],
        s['reparto_id'],
        s['producto_id'],
        enabledInt,
        s['threshold'] ?? 5,
        cloudMs,
      ],
    );
  }

  Future<void> restoreHabitualSettingFromCloud(Map<String, dynamic> h) async {
    final cloudUpdatedAt = h['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql:
          'SELECT updated_at, dirty FROM habitual_product_settings WHERE id = ? LIMIT 1',
      selectArgs: [Variable.withInt(h['id'] as int)],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    final enabledInt = (h['enabled'] is bool)
        ? ((h['enabled'] as bool) ? 1 : 0)
        : (h['enabled'] ?? 1);
    await customStatement(
      'INSERT INTO habitual_product_settings (id, reparto_id, producto_id, enabled, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(id) DO UPDATE SET '
      'reparto_id = excluded.reparto_id, '
      'producto_id = excluded.producto_id, '
      'enabled = excluded.enabled, '
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [h['id'], h['reparto_id'], h['producto_id'], enabledInt, cloudMs],
    );
  }

  Future<void> restoreFacturaFromCloud(Map<String, dynamic> f) async {
    final cloudUpdatedAt = f['updated_at'];
    final dirtyAndNewer = await _localIsDirtyAndNewer(
      selectSql: 'SELECT updated_at, dirty FROM facturas WHERE id = ? LIMIT 1',
      selectArgs: [Variable.withInt(f['id'] as int)],
      cloudUpdatedAt: cloudUpdatedAt,
    );
    if (dirtyAndNewer) return;
    final cloudMs = _isoToMs(cloudUpdatedAt);
    await customStatement(
      'INSERT INTO facturas (id, cliente_id, reparto_id, cbte_tipo, pto_vta, cbte_nro, fecha, importe_total, cae, cae_fch_vto, items_json, receptor_nombre, receptor_doc_tipo, receptor_doc_nro, pdf_path, created_at, updated_at, dirty) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0) '
      'ON CONFLICT(id) DO UPDATE SET '
      'cliente_id = excluded.cliente_id, '
      'reparto_id = excluded.reparto_id, '
      'cbte_tipo = excluded.cbte_tipo, '
      'pto_vta = excluded.pto_vta, '
      'cbte_nro = excluded.cbte_nro, '
      'fecha = excluded.fecha, '
      'importe_total = excluded.importe_total, '
      'cae = excluded.cae, '
      'cae_fch_vto = excluded.cae_fch_vto, '
      'items_json = excluded.items_json, '
      'receptor_nombre = excluded.receptor_nombre, '
      'receptor_doc_tipo = excluded.receptor_doc_tipo, '
      'receptor_doc_nro = excluded.receptor_doc_nro, '
      'pdf_path = excluded.pdf_path, '
      'created_at = excluded.created_at, '
      'updated_at = excluded.updated_at, '
      'dirty = 0',
      [
        f['id'],
        f['cliente_id'],
        f['reparto_id'],
        f['cbte_tipo'] ?? 11,
        f['pto_vta'],
        f['cbte_nro'],
        f['fecha'],
        (f['importe_total'] as num?)?.toDouble() ?? 0.0,
        f['cae'] ?? '',
        f['cae_fch_vto'] ?? '',
        f['items_json'] ?? '[]',
        f['receptor_nombre'] ?? '',
        f['receptor_doc_tipo'] ?? 99,
        f['receptor_doc_nro'] ?? '0',
        f['pdf_path'] ?? '',
        f['created_at'] ?? '',
        cloudMs,
      ],
    );
  }
}
