import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import '../../demo/demo_mode.dart';

/// Browser-local database backend used by the static public demo.
///
/// Uses drift's modern [WasmDatabase] over `sqlite3.wasm` + a drift web worker
/// (`drift_worker.js`), both committed under `web/` so the build bundles them.
/// Persistence is best-effort (IndexedDB/OPFS, in-memory fallback). The demo
/// clears and reseeds its fictional records every time it opens.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: kDemoMode ? kDemoWebDatabaseName : 'sodapp',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
