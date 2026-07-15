class MercadoPagoService {
  static Future<MpPreferenceResult?> createPreference({
    required String accessToken,
    required double amount,
    required String description,
    String? externalReference,
  }) async => null;

  static Future<int?> findApprovedPayment({
    required String accessToken,
    required String externalReference,
  }) async => null;
}

class MpPreferenceResult {
  final String preferenceId;
  final String initPoint;

  const MpPreferenceResult({
    required this.preferenceId,
    required this.initPoint,
  });
}
