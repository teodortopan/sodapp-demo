/// P0-5 (pre-release audit #5, extended per Codex review): shared guard so
/// EVERY invoice entry point blocks $0 lines the same way.
///
/// An item lands at price <= 0 when the entrega has no snapshot AND
/// getEffectivePrice found no configured price. Invoicing it would issue an
/// AFIP factura with an understated importeTotal, stored forever in
/// facturas. Callers must abort the flow (naming these productos) instead
/// of submitting to AFIP.
///
/// Items use the invoice-builder shape: {'nombre', 'cantidad', 'precioUnit',
/// 'subtotal'}.
List<String> unpricedFacturaItems(List<Map<String, dynamic>> items) {
  return [
    for (final it in items)
      if ((((it['precioUnit'] as num?) ?? 0).toDouble()) <= 0)
        it['nombre']?.toString() ?? '',
  ];
}
