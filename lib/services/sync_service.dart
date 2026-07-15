import 'package:flutter/foundation.dart';

/// Local-only compatibility surface for screens shared with the mobile app.
/// The public demo never opens a network connection or synchronizes data.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  void beginLocalWrites() {}
  void endLocalWrites() {}
  void scheduleSyncSoon() {}
  void startListening() {}
  Future<void> pullOnOpen() async {}

  Future<void> deleteClienteFromCloud(int clienteId) async {}
  Future<void> deleteProductFromCloud(int productId) async {}
  Future<void> deleteRepartoFromCloud(int repartoId) async {}

  Future<void> deleteResumenFromCloudByNaturalKey({
    required int fallbackRowId,
    required String userId,
    required Map<String, Object?> key,
  }) async {}

  Future<String?> downloadFacturaPdfFromCloud(
    int facturaId,
    String fileName,
  ) async => null;
}
