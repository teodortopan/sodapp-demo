class AfipService {
  final String cuit;
  final bool production;

  AfipService({required this.cuit, required this.production});

  Never _disabled() => throw const AfipException(
    'La facturacion electronica no esta disponible en la demo.',
  );

  Future<int> getLastCbteNro({required int ptoVta, int cbteTipo = 11}) async =>
      _disabled();

  Future<AfipInvoiceResult> createInvoice({
    required int ptoVta,
    required int cbteNro,
    required double importeTotal,
    int cbteTipo = 11,
    int concepto = 1,
    int docTipo = 99,
    int docNro = 0,
  }) async => _disabled();

  String generateQrUrl({
    required int ver,
    required String fecha,
    required int cbteTipo,
    required int ptoVta,
    required int cbteNro,
    required double importeTotal,
    required String cae,
    int moneda = 1,
    double cotizacion = 1,
    int docTipo = 99,
    String docNro = '0',
  }) => '';
}

class AfipInvoiceResult {
  final String cae;
  final String caeFchVto;
  final int cbteNro;
  final int ptoVta;
  final int cbteTipo;
  final String fechaCbte;

  const AfipInvoiceResult({
    required this.cae,
    required this.caeFchVto,
    required this.cbteNro,
    required this.ptoVta,
    required this.cbteTipo,
    required this.fechaCbte,
  });
}

class AfipException implements Exception {
  final String message;
  final String? responseBody;
  const AfipException(this.message, [this.responseBody]);

  @override
  String toString() => message;
}
