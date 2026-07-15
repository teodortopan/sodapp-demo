// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/screens/ruta_screen.dart').readAsStringSync();

  /// Read a slice of [length] chars starting from [anchor] inside [src],
  /// failing if the anchor isn't found.
  String _bodySlice(String anchor, int length) {
    final idx = src.indexOf(anchor);
    expect(
      idx,
      isNot(-1),
      reason: 'expected anchor in ruta_screen.dart: $anchor',
    );
    return src.substring(idx, (idx + length).clamp(0, src.length));
  }

  test('Ruta: wasPendingBeforePago is fully removed from ruta_screen.dart', () {
    // `_maybeAutoCompleteOnPago` no longer takes `wasPendingBeforePago`.
    // This concept must not survive ANYWHERE in the file — not just in the
    // function body. A leftover call site passing the removed named arg is a
    // compile error in normal code, but inside the ~2,265-line
    // `_showClientDetail` method the Dart front-end bails on type-inference
    // and treats the body as dynamic, so `flutter analyze`/`flutter build`
    // pass while the call throws NoSuchMethodError at runtime. Guard the
    // whole file with a plain substring check that the toolchain can't hide.
    expect(
      src,
      isNot(contains('wasPendingBeforePago')),
      reason:
          'A call site still passes the removed `wasPendingBeforePago` arg. '
          'It will throw NoSuchMethodError at runtime (hidden by the giant '
          '_showClientDetail method). Drop the named arg + its local.',
    );
  });

  test(
    'Ruta: _setClientStatus does not reset _expandedClienteId (out-of-order edits)',
    () {
      final body = _bodySlice('Future<void> _setClientStatus(', 600);
      expect(
        body.contains('_expandedClienteId = null'),
        isFalse,
        reason:
            'Regression: _setClientStatus must NOT reset _expandedClienteId. '
            'That reset snaps the expanded card back to the first-pending '
            'cliente (_activeClienteId fallback), which prevents the sodero '
            'from working clientes out of order.',
      );
    },
  );

  test(
    'Ruta: _clearDeferredStatusForActivity does not reset _expandedClienteId',
    () {
      // Covers BOTH the mounted and unmounted branches at :1330/:1334 — they
      // share the same function body, so scoping by anchor gives us both.
      final body = _bodySlice(
        'Future<void> _clearDeferredStatusForActivity(',
        600,
      );
      expect(
        body.contains('_expandedClienteId = null'),
        isFalse,
        reason:
            'Regression: _clearDeferredStatusForActivity must NOT reset '
            '_expandedClienteId in either the mounted or unmounted branch. '
            'It is called from _setEntrega and _setPago when a previously '
            'saltado cliente gets new activity. The reset would snap the '
            'expanded card back to the first-pending cliente.',
      );
    },
  );

  test('Ruta: payment auto-complete advances only the focused list card', () {
    final autoComplete = _bodySlice(
      'Future<bool> _maybeAutoCompleteOnPago(',
      900,
    );
    expect(
      autoComplete,
      contains('_shouldAdvanceListAfterCompleting(clienteId)'),
    );
    expect(
      autoComplete,
      contains('_advanceListAfterPaymentComplete(clienteId)'),
    );
    expect(autoComplete, isNot(contains('wasPendingBeforePago')));
    expect(
      autoComplete,
      isNot(contains("_getClientStatus(clienteId) != 'pending'")),
      reason:
          'An explicit payment-method tap is the finalization action. Stale '
          'or deferred status state must not block auto-Listo after the pago '
          'has been saved.',
    );
    expect(
      autoComplete,
      contains("if (_getClientStatus(clienteId) == 'completed') return true"),
    );

    final shouldAdvance = _bodySlice(
      'bool _shouldAdvanceListAfterCompleting(',
      500,
    );
    expect(
      shouldAdvance,
      contains('if (_mapExpanded || _expandedClienteId == -1)'),
    );
    expect(shouldAdvance, contains('return expandedId == clienteId'));
    expect(shouldAdvance, contains('return _activeClienteId == clienteId'));

    final advance = _bodySlice('void _advanceListAfterPaymentComplete(', 1300);
    expect(advance, contains("_getClientStatus(candidate.id) == 'pending'"));
    expect(advance, contains('_expandedClienteId = nextClienteId ?? -1'));
    expect(advance, contains('_ensureListCardVisible(nextClienteId)'));
  });

  test(
    'Ruta: payment auto-complete sheet path closes and opens next panel',
    () {
      final selectPago = _bodySlice('Future<void> selectPago(', 1200);
      expect(selectPago, contains('await _setPago(cliente.id, metodo, monto)'));
      expect(
        selectPago,
        contains(
          'final completed = await _maybeAutoCompleteOnPago(cliente.id)',
        ),
      );
      expect(selectPago, isNot(contains('wasPendingBeforePago')));
      expect(selectPago, contains('Navigator.of(sheetCtx).pop()'));
      expect(selectPago, contains('_openNextPendingPanelAfter(cliente.id)'));
    },
  );

  test('Ruta: every status button advances + inline Saltar always visible', () {
    // Surface B — bottom-sheet footer routes through setStatus(). Forward
    // progress must now open the next pending client's sheet (not just pop),
    // for ANY status (Ausente / Saltar / Listo), mirroring selectPago.
    final setStatus = _bodySlice(
      'Future<void> setStatus(String status) async {',
      2200,
    );
    expect(
      setStatus,
      contains('_openNextPendingPanelAfter(cliente.id)'),
      reason:
          'setStatus forward path must advance to the next pending client '
          '(close current sheet, open next) for any status, not just Listo.',
    );
    expect(
      setStatus,
      contains('_confirmSaltarIfActivity('),
      reason:
          'Saltar is always visible now, but it can delete today\'s '
          'entregas/pago. The sheet path must confirm before applying it.',
    );
    expect(
      setStatus.indexOf('_confirmSaltarIfActivity('),
      lessThan(setStatus.indexOf("_setClientStatus(cliente.id, status)")),
      reason:
          'The sheet must ask for confirmation before the deferred status '
          'write can delete activity.',
    );

    // Surface A — inline dropdown status row (_buildActiveInline). Slice from
    // the row builder so we do NOT pick up the dead commented-out block
    // (lines ~3180–5013), which still contains an _hasVisitActivity guard.
    final inlineRow = _bodySlice(
      "final hasStatus = currentStatus != 'pending';",
      6000,
    );
    expect(
      inlineRow,
      isNot(contains('if (!_hasVisitActivity(cliente.id)) ...[')),
      reason:
          'The inline Saltar button must always render — the visit-activity '
          'guard around it was removed so Saltar is never hidden.',
    );
    final advanceCount = '_advanceListAfterPaymentComplete(cliente.id)'
        .allMatches(inlineRow)
        .length;
    expect(
      advanceCount,
      greaterThanOrEqualTo(4),
      reason:
          'Each inline status handler (No compró / Ausente / Saltar / Listo) '
          'must advance to the next pending client on forward progress. '
          'Found $advanceCount advance calls in the inline row (expected >= 4).',
    );
    expect(
      inlineRow,
      contains('_confirmSaltarIfActivity('),
      reason:
          'Inline Saltar is always visible and must confirm before deleting '
          'today\'s activity.',
    );
    expect(
      inlineRow.indexOf('_confirmSaltarIfActivity('),
      lessThan(inlineRow.indexOf("_setClientStatus(cliente.id, 'deferred')")),
      reason:
          'Inline Saltar must ask for confirmation before writing deferred.',
    );
  });

  test(
    'Ruta: Saltar confirmation documents the destructive activity clear',
    () {
      expect(src, contains('bool _saltarWouldClearActivity(int clienteId)'));
      expect(src, contains('_hasEntregaActivity(clienteId)'));
      expect(src, contains('_clientePagos[clienteId] != null'));
      expect(src, contains('Future<bool> _confirmSaltarIfActivity('));
      expect(src, contains('Saltar y borrar'));
    },
  );

  test('Ruta: data/settings reloads do not force the visible map/list mode', () {
    expect(src, contains('bool _mapPreferenceHydrated = false'));
    expect(
      src,
      contains('void _hydrateVisibleMapModeOnce(bool mapEnabled)'),
      reason:
          'The persisted map preference should hydrate the visible mode once, '
          'not on every DB/settings reload.',
    );
    expect(src, contains('if (_mapPreferenceHydrated) return'));
    final loadDataMapBlock = _bodySlice('_mapEnabled = mapEnabled;', 180);
    expect(
      loadDataMapBlock,
      contains('_hydrateVisibleMapModeOnce(mapEnabled)'),
    );
    expect(
      loadDataMapBlock,
      isNot(contains('_mapExpanded = mapEnabled;')),
      reason:
          '_loadData may hydrate the visible mode once, but must not assign '
          '_mapExpanded directly on every reload.',
    );
    expect(
      src,
      contains('if (_mapExpanded) return _buildExpandedMap();'),
      reason:
          'The rendered view must follow the current visible mode, not the '
          'persisted setting that can reload in the background.',
    );
  });
}
