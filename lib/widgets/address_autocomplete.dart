import 'dart:async';

import 'package:flutter/material.dart';

import '../services/places_service.dart';

/// Field builder used by [AddressAutocomplete] on mobile. Mirrors the web
/// variant's API (callers control the underlying [TextField]'s styling)
/// so call sites can keep using the same `_buildField` look already used
/// elsewhere in `clientes_screen.dart`.
typedef AddressFieldBuilder =
    Widget Function(
      BuildContext context,
      TextEditingController controller,
      FocusNode focusNode,
      VoidCallback onFieldSubmitted,
    );

typedef AddressSelectedCallback =
    void Function(String formattedAddress, double lat, double lng);

/// Mobile-side Google Places Autocomplete dropdown for the cliente address
/// field. Twin of `lib/screens/web/widgets/address_autocomplete.dart` but
/// styled with the existing mobile palette (`#0F1B2D` Material, `lightBlue`
/// accent) instead of VaTheme tokens.
///
/// Offline behaviour: [PlacesService.autocomplete] returns `[]` on any
/// network failure / missing key, so the dropdown stays closed and the
/// operator can still type and save the address — the device-side geocoder
/// in `ruta_screen._geocodeClients` fills `lat`/`lng` later.
class AddressAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final AddressFieldBuilder fieldBuilder;
  final AddressSelectedCallback onAddressSelected;
  final ValueChanged<String>? onChanged;
  final double optionsMaxWidth;
  final double optionsMaxHeight;

  const AddressAutocomplete({
    super.key,
    required this.controller,
    required this.fieldBuilder,
    required this.onAddressSelected,
    this.onChanged,
    this.optionsMaxWidth = 360,
    this.optionsMaxHeight = 260,
  });

  @override
  State<AddressAutocomplete> createState() => _AddressAutocompleteState();
}

class _AddressAutocompleteState extends State<AddressAutocomplete> {
  static const _surface = Color(0xFF0F1B2D);
  static const _border = Color(0xFF1A2A40);
  static const _accent = Color(0xFF1292D3);

  final FocusNode _focusNode = FocusNode();
  String _sessionToken = PlacesService.newSessionToken();

  Timer? _debounceTimer;
  Completer<List<PlacePrediction>>? _pendingCompleter;
  String? _lastMirroredText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _debounceTimer?.cancel();
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete(const []);
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final text = widget.controller.text;
    if (text == _lastMirroredText) return;
    _lastMirroredText = text;
    widget.onChanged?.call(text);
  }

  Future<List<PlacePrediction>> _runQuery(String query) {
    _debounceTimer?.cancel();
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete(const []);
    }
    final trimmed = query.trim();
    if (trimmed.length < 3) return Future.value(const []);

    final completer = Completer<List<PlacePrediction>>();
    _pendingCompleter = completer;
    final token = _sessionToken;
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (completer.isCompleted) return;
      final results = await PlacesService.instance.autocomplete(
        trimmed,
        sessionToken: token,
      );
      if (!completer.isCompleted) completer.complete(results);
    });
    return completer.future;
  }

  Future<void> _onPredictionSelected(PlacePrediction p) async {
    final token = _sessionToken;
    _sessionToken = PlacesService.newSessionToken();

    final details = await PlacesService.instance.details(
      p.placeId,
      sessionToken: token,
    );
    if (details == null) {
      _setControllerText(p.description);
      widget.onChanged?.call(p.description);
      return;
    }
    _setControllerText(details.formattedAddress);
    widget.onChanged?.call(details.formattedAddress);
    widget.onAddressSelected(
      details.formattedAddress,
      details.lat,
      details.lng,
    );
  }

  void _setControllerText(String text) {
    _lastMirroredText = text;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<PlacePrediction>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (p) => p.description,
      optionsBuilder: (value) => _runQuery(value.text),
      onSelected: _onPredictionSelected,
      fieldViewBuilder: widget.fieldBuilder,
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: _surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: widget.optionsMaxHeight,
                maxWidth: widget.optionsMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final opt = options.elementAt(index);
                        final main = opt.secondaryText == null
                            ? opt.description
                            : opt.description.replaceFirst(
                                RegExp(
                                  ', ${RegExp.escape(opt.secondaryText!)}\$',
                                ),
                                '',
                              );
                        return InkWell(
                          onTap: () => onSelected(opt),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: _accent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        main,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (opt.secondaryText != null &&
                                          opt.secondaryText!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            opt.secondaryText!,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.6,
                                              ),
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Required Places ToS attribution.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _border, width: 1)),
                    ),
                    child: Text(
                      'Powered by Google',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
