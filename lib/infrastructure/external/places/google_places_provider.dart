import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../domain/models/geo_point.dart';
import '../../../domain/models/poi_candidate.dart';
import '../../../domain/services/places_provider.dart';
import '../../logging/app_logger.dart';

/// Google Places API (New) 実装 — searchNearby POST
class GooglePlacesProvider implements PlacesProvider {
  static const String _baseUrl = 'https://places.googleapis.com/v1/places:searchNearby';

  String? get _apiKey => dotenv.env['GOOGLE_PLACES_API_KEY'];

  static const String _fieldMask = 'places.displayName,places.name,places.types,places.location';

  @override
  Future<List<PoiCandidate>> searchNearby({
    required GeoPoint point,
    required int radiusMeters,
    List<String>? categories,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Google Places API key is not configured');
    }

    final type = categories?.isNotEmpty == true ? categories!.first : 'point_of_interest';

    final body = {
      'includedTypes': [type],
      'maxResultCount': 20,
      'locationRestriction': {
        'circle': {
          'center': {
            'latitude': point.lat,
            'longitude': point.lng,
          },
          'radius': radiusMeters.toDouble(),
        },
      },
      'languageCode': 'ja',
    };

    try {
      if (kDebugMode) {
        AppLogger.d('Places API (New) POST $_baseUrl type=$type');
      }
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey!,
          'X-Goog-FieldMask': _fieldMask,
        },
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          AppLogger.d('Places API (New) response statusCode=${response.statusCode}');
        }
        if (response.statusCode == 429) {
          throw Exception('API rate limit exceeded');
        }
        throw Exception('Places API HTTP error: statusCode=${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // New API は HTTP 200 でも JSON 内で error を返す場合がある
      final error = data['error'];
      if (error != null && error is Map<String, dynamic>) {
        final message = error['message'] as String? ?? '';
        final code = error['code'] as int?;
        AppLogger.w('Places API (New) error: code=$code message=$message');
        throw Exception('Places API failed: $message');
      }

      final places = data['places'] as List?;
      if (places == null) {
        if (kDebugMode) {
          AppLogger.d('Places API (New) response type=$type results=0');
        }
        return [];
      }

      if (kDebugMode) {
        AppLogger.d('Places API (New) response type=$type statusCode=${response.statusCode} results=${places.length}');
      }

      return places
          .cast<Map<String, dynamic>>()
          .map((p) => _parsePlaceResult(p, point))
          .toList();
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Places search failed: $e');
    }
  }

  PoiCandidate _parsePlaceResult(Map<String, dynamic> place, GeoPoint origin) {
    String name = '';
    final displayName = place['displayName'];
    if (displayName is Map<String, dynamic>) {
      name = displayName['text'] as String? ?? '';
    }

    final types = place['types'] as List?;
    final category = _extractCategory(types);

    int? distanceMeters;
    final location = place['location'];
    if (location is Map<String, dynamic>) {
      final lat = location['latitude'] as num?;
      final lng = location['longitude'] as num?;
      if (lat != null && lng != null) {
        distanceMeters = _calculateDistance(
          origin.lat,
          origin.lng,
          lat.toDouble(),
          lng.toDouble(),
        ).round();
      }
    }

    String? sourceId;
    final resourceName = place['name'] as String?;
    if (resourceName != null && resourceName.startsWith('places/')) {
      sourceId = resourceName.substring(7);
    }

    return PoiCandidate(
      name: name,
      category: category,
      distanceMeters: distanceMeters,
      sourceId: sourceId,
    );
  }

  String _extractCategory(List? types) {
    if (types == null || types.isEmpty) return 'point_of_interest';

    final priority = ['park', 'cafe', 'restaurant', 'train_station', 'convenience_store'];
    for (final p in priority) {
      if (types.contains(p)) return p;
    }
    return types.first as String;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (3.141592653589793 / 180);
}
