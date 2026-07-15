import 'dart:math';

class PlacePrediction {
  final String placeId;
  final String description;
  final String? secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    this.secondaryText,
  });
}

class PlaceDetails {
  final String formattedAddress;
  final double lat;
  final double lng;

  const PlaceDetails({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });
}

/// Address lookup is deliberately disabled in the static portfolio demo.
class PlacesService {
  PlacesService._();
  static final PlacesService instance = PlacesService._();

  static String newSessionToken() {
    final random = Random();
    return List.generate(4, (_) {
      return random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0');
    }).join();
  }

  Future<List<PlacePrediction>> autocomplete(
    String query, {
    required String sessionToken,
  }) async => const [];

  Future<PlaceDetails?> details(
    String placeId, {
    required String sessionToken,
  }) async => null;
}
