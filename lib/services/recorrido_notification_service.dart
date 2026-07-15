import 'package:flutter/foundation.dart';

/// Browser-only compatibility surface. The demo never posts OS notifications.
class RecorridoNotificationService {
  RecorridoNotificationService._();
  static final RecorridoNotificationService instance =
      RecorridoNotificationService._();

  VoidCallback? onTerminarRequested;

  Future<bool> ensureNotificationPermission() async => false;

  Future<void> start({
    required int baseWhenMillis,
    required String repartoNombre,
    required int visited,
    required int total,
  }) async {}

  Future<void> update({
    required int visited,
    required int total,
    String? repartoNombre,
    int? baseWhenMillis,
  }) async {}

  Future<void> stop() async {}
}
