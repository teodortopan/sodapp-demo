import 'package:flutter/material.dart';

const bool kDemoMode = true;

/// In demo the sodero can run the FULL live delivery loop against the seeded
/// example clients: start/end a recorrido, pick the working day, load the truck
/// (carga), mark entregas, take pagos (efectivo/transferencia/no_pago), add
/// gastos, and close the day (cierre + resumen). What stays LOCKED: the client
/// roster + config, product/price config, invoicing (factura), Mercado Pago,
/// per-order price overrides, editing past records, and account settings.
///
/// Live-flow guard sites read `if (!kDemoAllowLiveFlow && blockDemoAction(...))`
/// so they short-circuit (no upgrade snack, action proceeds) while staying
/// documented and trivially reversible. The locked sites keep the bare
/// `blockDemoAction(...)` / `readOnly = kDemoMode` guards untouched.
const bool kDemoAllowLiveFlow = true;

const String kDemoUserId = 'demo-user-local';
const String kDemoEmail = 'demo@sodapp.local';
const String kDemoDatabaseFileName = 'sodapp_demo.sqlite';
const String kDemoWebDatabaseName = 'sodapp_demo';
const String kDemoUpgradeMessage =
    'Demo: pasate a la app completa para usar esta funcion.';

bool _demoUpgradeSnackActive = false;

void showDemoUpgradeSnack(BuildContext context, {String? message}) {
  if (_demoUpgradeSnackActive) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  _demoUpgradeSnackActive = true;
  messenger
      .showSnackBar(
        SnackBar(
          content: Text(message ?? kDemoUpgradeMessage),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      )
      .closed
      .whenComplete(() {
        _demoUpgradeSnackActive = false;
      });
}

bool blockDemoAction(BuildContext context, {String? message}) {
  if (!kDemoMode) return false;
  showDemoUpgradeSnack(context, message: message);
  return true;
}
